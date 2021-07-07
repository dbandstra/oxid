const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
const wav = @import("zig-wav");
const zang = @import("zang");
const mod = @import("modules");
const passets = @import("root").passets;
const generated = @import("audio/generated.zig");

pub const SoundParams = union(enum) {
    accelerate: generated.AccelerateVoice.NoteParams,
    coin: generated.CoinVoice.NoteParams,
    drop_web: generated.DropWebVoice.NoteParams,
    explosion: generated.ExplosionVoice.NoteParams,
    laser: generated.LaserVoice.NoteParams,
    menu_backoff: generated.MenuBackoffVoice.NoteParams,
    menu_blip: generated.MenuBlipVoice.NoteParams,
    menu_ding: generated.MenuDingVoice.NoteParams,
    power_up: generated.PowerUpVoice.NoteParams,
    wave_begin: generated.WaveBeginVoice.NoteParams,
    sample: Sample,
};

pub const Sample = enum {
    extra_life,
    player_death,
    player_crumble,
    monster_impact,
};

fn getSampleFilename(sample: Sample) []const u8 {
    return switch (sample) {
        .extra_life => "sfx_sounds_powerup4.wav",
        .player_death => "player_death.wav",
        .player_crumble => "sfx_exp_short_soft10.wav",
        .monster_impact => "sfx_sounds_impact1.wav",
    };
}

fn readWav(hunk: *Hunk, filename: []const u8) !mod.Sampler.Sample {
    // temporary allocations in the high hunk side, persistent in the low side
    const mark = hunk.getHighMark();
    defer hunk.freeToHighMark(mark);

    const contents = try passets.loadAsset(&hunk.low().allocator, &hunk.high(), filename);

    var fbs = std.io.fixedBufferStream(contents);

    const preloaded = try wav.preload(fbs.reader());

    return mod.Sampler.Sample{
        .num_channels = preloaded.num_channels,
        .sample_rate = preloaded.sample_rate,
        .format = switch (preloaded.format) {
            .unsigned8 => .unsigned8,
            .signed16_lsb => .signed16_lsb,
            .signed24_lsb => .signed24_lsb,
            .signed32_lsb => .signed32_lsb,
        },
        // don't need to allocate new memory or call Loader.load, because
        // contents has already been loaded and we use wav data as-is from
        // the file
        .data = contents[fbs.pos .. fbs.pos + preloaded.getNumBytes()],
    };
}

// crawl all audio modules and get the highest num_temps value
const max_temps = blk: {
    var highest: usize = 0;
    inline for (@typeInfo(generated).Struct.decls) |decl| {
        switch (decl.data) {
            .Type => |T| {
                if (@hasDecl(T, "num_temps") and T.num_temps > highest)
                    highest = T.num_temps;
            },
            else => {},
        }
    }
    break :blk highest;
};

const MultiModule = union(enum) {
    const num_outputs = 1;
    const num_temps = max_temps;
    const Params = struct {
        sample_rate: f32,
        note_on: bool,
        sound_params: SoundParams,
    };

    none,
    accelerate: generated.AccelerateVoice,
    coin: generated.CoinVoice,
    drop_web: generated.DropWebVoice,
    explosion: generated.ExplosionVoice,
    laser: generated.LaserVoice,
    menu_backoff: generated.MenuBackoffVoice,
    menu_blip: generated.MenuBlipVoice,
    menu_ding: generated.MenuDingVoice,
    power_up: generated.PowerUpVoice,
    wave_begin: generated.WaveBeginVoice,
    sample: mod.Sampler,

    fn paint(
        self: *MultiModule,
        loaded_samples: *const [@typeInfo(Sample).Enum.fields.len]mod.Sampler.Sample,
        span: zang.Span,
        outputs: [num_outputs][]f32,
        temps: [num_temps][]f32,
        note_id_changed: bool,
        params: Params,
    ) void {
        inline for (@typeInfo(SoundParams).Union.fields) |field, field_index| {
            if (@enumToInt(params.sound_params) == field_index) {
                // locate the field with the same name in the Module union
                comptime var T: type = undefined;
                comptime var module_tag_index: comptime_int = undefined;
                inline for (@typeInfo(MultiModule).Union.fields) |f, i| {
                    if (comptime std.mem.eql(u8, f.name, field.name)) {
                        T = f.field_type;
                        module_tag_index = i;
                        break;
                    }
                } else @compileError("Module union has no field called '" ++ field.name ++ "'");

                // are we already playing this module type in this voice slot?
                // if not, we need to initialize the module
                if (@enumToInt(self.*) != module_tag_index)
                    self.* = @unionInit(MultiModule, field.name, T.init());

                // paint. first we need to convert the NoteParams to Params, by adding the
                // sample_rate field.
                var module_params: T.Params = undefined;

                if (T == mod.Sampler) {
                    module_params = .{
                        .sample_rate = params.sample_rate,
                        .sample = loaded_samples[@enumToInt(@field(params.sound_params, field.name))],
                        .channel = 0,
                        .loop = false,
                    };
                } else {
                    const note_params: T.NoteParams = @field(params.sound_params, field.name);

                    inline for (@typeInfo(T.Params).Struct.fields) |f| {
                        @field(module_params, f.name) =
                            if (comptime std.mem.eql(u8, f.name, "sample_rate"))
                            params.sample_rate
                        else
                            @field(note_params, f.name);
                    }
                }

                @field(self, field.name).paint(
                    span,
                    outputs,
                    temps[0..T.num_temps].*,
                    note_id_changed,
                    module_params,
                );
            }
        }
    }
};

pub const State = struct {
    // we have only 8 global voice slots. each incoming sound effect takes over the "stalest" one.
    const Voice = struct {
        module: MultiModule,
        trigger: zang.Trigger(MultiModule.Params),
    };

    const num_voices = 8;

    loaded_samples: [@typeInfo(Sample).Enum.fields.len]mod.Sampler.Sample,

    dispatcher: zang.Notes(MultiModule.Params).PolyphonyDispatcher(num_voices),
    voices: [num_voices]Voice,
    impulse_frame: usize,
    next_note_id: usize,
    iq: zang.Notes(MultiModule.Params).ImpulseQueue,

    out_buf: []f32,
    tmp_bufs: [max_temps][]f32,

    volume: u32,
    sample_rate: f32,

    // call this in the main thread before the audio device is set up.
    // allocates some permanent stuff in the low side of the hunk.
    pub fn init(self: *State, hunk: *Hunk, volume: u32, sample_rate: f32, audio_buffer_size: usize) !void {
        const mark = hunk.getLowMark();
        errdefer hunk.freeToLowMark(mark);

        for (self.loaded_samples) |*loaded_sample, i| {
            const sample = @intToEnum(Sample, @intCast(std.meta.Tag(Sample), i));
            loaded_sample.* = try readWav(hunk, getSampleFilename(sample));
        }

        self.dispatcher = zang.Notes(MultiModule.Params).PolyphonyDispatcher(num_voices).init();
        for (self.voices) |*voice| {
            voice.* = .{
                .module = .none,
                .trigger = zang.Trigger(MultiModule.Params).init(),
            };
        }
        self.impulse_frame = 0;
        self.next_note_id = 1;
        self.iq = zang.Notes(MultiModule.Params).ImpulseQueue.init();

        self.out_buf = try hunk.low().allocator.alloc(f32, audio_buffer_size);
        for (self.tmp_bufs) |*tmp_buf|
            tmp_buf.* = try hunk.low().allocator.alloc(f32, audio_buffer_size);

        self.volume = volume;
        self.sample_rate = sample_rate;
    }

    // called in the main thread while the audio thread is locked
    pub fn pushSound(self: *State, sound_params: SoundParams) void {
        self.iq.push(self.impulse_frame, self.next_note_id, .{
            .sample_rate = self.sample_rate,
            .note_on = true,
            .sound_params = sound_params,
        });
        self.next_note_id +%= 1;

        // if the exact same sound were to play twice on the same impulse frame, it would be twice
        // as loud. mitigate this by starting each new sound at a slightly different impulse frame.
        // this is basically a hack, but it's better than nothing (although it won't help much with
        // square wave-based sounds...)
        if (self.impulse_frame + 16 < self.out_buf.len)
            self.impulse_frame += 16;
    }

    // called in the main thread while the audio thread is locked. this is called if sound is
    // disabled entirely.
    pub fn reset(self: *State) void {
        // with sound disabled, we might not be calling the paint function. therefore any modules
        // that were playing before sound was disabled will be effectively paused. we don't want
        // this, so clear out all state.
        for (self.voices) |*voice|
            voice.trigger.reset();
        _ = self.iq.consume();
        self.impulse_frame = 0;
    }

    // called in the audio thread
    pub fn paint(self: *State) []f32 {
        const span = zang.Span.init(0, self.out_buf.len);

        zang.zero(span, self.out_buf);

        const iap = self.iq.consume();
        const poly_iap = self.dispatcher.dispatch(iap);
        for (self.voices) |*voice, i| {
            var ctr = voice.trigger.counter(span, poly_iap[i]);
            while (voice.trigger.next(&ctr)) |result| {
                voice.module.paint(
                    &self.loaded_samples,
                    result.span,
                    .{self.out_buf},
                    self.tmp_bufs,
                    result.note_id_changed,
                    result.params,
                );
            }
        }

        self.impulse_frame = 0;

        return self.out_buf;
    }
};
