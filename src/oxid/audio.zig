const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
const wav = @import("zig-wav");
const zang = @import("zang");
const mod = @import("modules");
const passets = @import("root").passets;
const generated = @import("audio/generated.zig");

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

fn makeSample(preloaded: wav.PreloadedInfo, data: []const u8) mod.Sampler.Sample {
    return .{
        .num_channels = preloaded.num_channels,
        .sample_rate = preloaded.sample_rate,
        .format = switch (preloaded.format) {
            .unsigned8 => .unsigned8,
            .signed16_lsb => .signed16_lsb,
            .signed24_lsb => .signed24_lsb,
            .signed32_lsb => .signed32_lsb,
        },
        .data = data,
    };
}

fn readWav(hunk: *Hunk, filename: []const u8) !mod.Sampler.Sample {
    // temporary allocations in the high hunk side, persistent in the low side
    const mark = hunk.getHighMark();
    defer hunk.freeToHighMark(mark);

    const contents = try passets.loadAsset(&hunk.low().allocator, &hunk.high(), filename);

    var fbs = std.io.fixedBufferStream(contents);
    var reader = fbs.reader();

    const Loader = wav.Loader(@TypeOf(reader), false);
    const preloaded = try Loader.preload(&reader);

    // don't need to allocate new memory or call Loader.load, because contents
    // has already been loaded and we use wav data as-is from the file
    return makeSample(preloaded, contents[fbs.pos .. fbs.pos + preloaded.getNumBytes()]);
}

pub const Sample = enum {
    extra_life,
    player_death,
    player_crumble,
    monster_impact,
};

const LoadedSamples = struct {
    samples: [@typeInfo(Sample).Enum.fields.len]mod.Sampler.Sample,

    fn init(hunk: *Hunk) !LoadedSamples {
        var self: LoadedSamples = undefined;
        for (self.samples) |_, i| {
            const s = @intToEnum(Sample, @intCast(@TagType(Sample), i));
            self.samples[i] = try readWav(hunk, switch (s) {
                .extra_life => "sfx_sounds_powerup4.wav",
                .player_death => "player_death.wav",
                .player_crumble => "sfx_exp_short_soft10.wav",
                .monster_impact => "sfx_sounds_impact1.wav",
            });
        }
        return self;
    }

    fn get(self: *const LoadedSamples, sample: Sample) mod.Sampler.Sample {
        return self.samples[@enumToInt(sample)];
    }
};

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

pub const Module = union(enum) {
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
};

pub const MultiModule = struct {
    pub const num_outputs = 1;
    pub const num_temps = max_temps;
    pub const Params = struct {
        sample_rate: f32,
        note_on: bool, // required by zang's polyphony dispatcher
        sound_params: SoundParams,
    };

    module: Module,

    pub fn init() MultiModule {
        return .{
            .module = .none,
        };
    }

    pub fn paint(
        self: *MultiModule,
        loaded_samples: *const LoadedSamples,
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
                inline for (@typeInfo(Module).Union.fields) |f, i| {
                    if (comptime std.mem.eql(u8, f.name, field.name)) {
                        T = f.field_type;
                        module_tag_index = i;
                        break;
                    }
                } else @compileError("Module union has no field called '" ++ field.name ++ "'");

                // are we already playing this module type in this voice slot?
                // if not, we need to initialize the module
                if (@enumToInt(self.module) != module_tag_index)
                    self.module = @unionInit(Module, field.name, T.init());

                // paint. first we need to convert the NoteParams to Params, by adding the
                // sample_rate field.
                var module_params: T.Params = undefined;

                if (T == mod.Sampler) {
                    module_params = .{
                        .sample_rate = params.sample_rate,
                        .sample = loaded_samples.get(@field(params.sound_params, field.name)),
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

                @field(self.module, field.name).paint(
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

pub const MainModule = struct {
    // we have only 8 global voice slots. each incoming sound effect takes over the "stalest" one.
    const Voice = struct {
        module: MultiModule,
        trigger: zang.Trigger(MultiModule.Params),
    };

    const num_voices = 8;

    dispatcher: zang.Notes(MultiModule.Params).PolyphonyDispatcher(num_voices),
    voices: [num_voices]Voice,
    next_note_id: usize,
    iq: zang.Notes(MultiModule.Params).ImpulseQueue,

    loaded_samples: LoadedSamples,

    out_buf: []f32,
    tmp_bufs: [max_temps][]f32,

    volume: u32,
    sample_rate: f32,

    // call this in the main thread before the audio device is set up.
    // allocates some permanent stuff in the low side of the hunk.
    pub fn init(self: *MainModule, hunk: *Hunk, volume: u32, sample_rate: f32, audio_buffer_size: usize) !void {
        const mark = hunk.getLowMark();
        errdefer hunk.freeToLowMark(mark);

        self.dispatcher = zang.Notes(MultiModule.Params).PolyphonyDispatcher(num_voices).init();
        for (self.voices) |*voice| {
            voice.* = .{
                .module = MultiModule.init(),
                .trigger = zang.Trigger(MultiModule.Params).init(),
            };
        }
        self.next_note_id = 1;
        self.iq = zang.Notes(MultiModule.Params).ImpulseQueue.init();
        self.loaded_samples = try LoadedSamples.init(hunk);
        self.out_buf = try hunk.low().allocator.alloc(f32, audio_buffer_size);
        for (self.tmp_bufs) |*tmp_buf|
            tmp_buf.* = try hunk.low().allocator.alloc(f32, audio_buffer_size);
        self.volume = volume;
        self.sample_rate = sample_rate;
    }

    // called in the main thread while the audio thread is locked
    pub fn pushSound(self: *MainModule, sound_params: SoundParams) void {
        const impulse_frame: usize = 0;

        self.iq.push(impulse_frame, self.next_note_id, .{
            .sample_rate = self.sample_rate,
            .note_on = true,
            .sound_params = sound_params,
        });
        self.next_note_id +%= 1;
    }

    // called in the audio thread
    pub fn paint(self: *MainModule) []f32 {
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

        return self.out_buf;
    }
};
