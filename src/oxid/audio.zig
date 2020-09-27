const builtin = @import("builtin");
const build_options = @import("build_options");
const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
const wav = @import("zig-wav");
const zang = @import("zang");
const game = @import("game.zig");
const c = @import("components.zig");
const MenuSounds = @import("../oxid_common.zig").MenuSounds;

const generated = @import("audio/generated.zig");
pub const AccelerateVoice = generated.AccelerateVoice;
pub const CoinVoice = generated.CoinVoice;
pub const ExplosionVoice = generated.ExplosionVoice;
pub const LaserVoice = generated.LaserVoice;
pub const MenuBackoffVoice = generated.MenuBackoffVoice;
pub const MenuBlipVoice = generated.MenuBlipVoice;
pub const MenuDingVoice = generated.MenuDingVoice;
pub const PowerUpVoice = generated.PowerUpVoice;
pub const WaveBeginVoice = generated.WaveBeginVoice;

fn makeSample(preloaded: wav.PreloadedInfo, data: []const u8) zang.Sample {
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

fn readWav(hunk: *Hunk, filename: []const u8) !zang.Sample {
    // temporary allocations in the high hunk side, persistent in the low side
    const mark = hunk.getHighMark();
    defer hunk.freeToHighMark(mark);

    if (builtin.arch == .wasm32) {
        // wasm build: assets were prefetched in JS code and made available via
        // the getAsset API
        const web = @import("../web.zig");

        const file_path = try std.fs.path.join(&hunk.high().allocator, &[_][]const u8{
            "assets",
            filename,
        });

        const buf = web.getAsset(file_path) orelse {
            return error.AssetNotFound;
        };

        var fbs = std.io.fixedBufferStream(buf);
        var stream = fbs.inStream();

        const Loader = wav.Loader(@TypeOf(stream), false);
        const preloaded = try Loader.preload(&stream);

        // don't need to allocate new memory or call Loader.load, because:
        // 1. `buf` is always available (provided from the JS side) and
        //    contains the wav file contents, and
        // 2. wavs are decoded and ready to go already, so we can just take a
        //    slice into the file contents.
        return makeSample(preloaded, buf[fbs.pos .. fbs.pos + preloaded.getNumBytes()]);
    } else {
        // non-wasm build: load assets from disk, allocating new memory to
        // store them
        const file_path = try std.fs.path.join(&hunk.high().allocator, &[_][]const u8{
            build_options.assets_path,
            filename,
        });

        const file = try std.fs.cwd().openFile(file_path, .{});
        var stream = file.inStream();

        const Loader = wav.Loader(@TypeOf(stream), true);
        const preloaded = try Loader.preload(&stream);

        const num_bytes = preloaded.getNumBytes();
        var data = try hunk.low().allocator.alloc(u8, num_bytes);
        try Loader.load(&stream, preloaded, data);

        return makeSample(preloaded, data);
    }
}

pub const Sample = enum {
    drop_web,
    extra_life,
    player_death,
    player_crumble,
    monster_impact,
};

const LoadedSamples = struct {
    samples: [@typeInfo(Sample).Enum.fields.len]zang.Sample,

    fn init(hunk: *Hunk) !LoadedSamples {
        var self: LoadedSamples = undefined;
        for (self.samples) |_, i| {
            const s = @intToEnum(Sample, @intCast(@TagType(Sample), i));
            self.samples[i] = try readWav(hunk, switch (s) {
                .drop_web => "sfx_sounds_interaction5.wav",
                .extra_life => "sfx_sounds_powerup4.wav",
                .player_death => "player_death.wav",
                .player_crumble => "sfx_exp_short_soft10.wav",
                .monster_impact => "sfx_sounds_impact1.wav",
            });
        }
        return self;
    }

    fn get(self: *const LoadedSamples, sample: Sample) zang.Sample {
        return self.samples[@enumToInt(sample)];
    }
};

pub const SamplerNoteParams = struct {
    sample: zang.Sample,
    channel: usize,
    loop: bool,
};

// this object lives on the audio thread. use `sync` to pass it information from the main thread.
fn GameSoundWrapper(comptime ModuleType: type) type {
    const NoteParamsType = if (ModuleType == zang.Sampler)
        SamplerNoteParams
    else
        ModuleType.NoteParams;

    return struct {
        module: ModuleType,
        trigger: zang.Trigger(NoteParamsType),
        iq: zang.Notes(NoteParamsType).ImpulseQueue,
        idgen: zang.IdGenerator,

        fn init() @This() {
            return .{
                .module = ModuleType.init(),
                .trigger = zang.Trigger(NoteParamsType).init(),
                .iq = zang.Notes(NoteParamsType).ImpulseQueue.init(),
                .idgen = zang.IdGenerator.init(),
            };
        }

        // call from main thread with audio thread locked. communicate information from main thread to audio thread
        fn sync(self: *@This(), reset: bool, impulse_frame: usize, maybe_params: ?NoteParamsType) void {
            if (reset) {
                self.trigger.reset();
                _ = self.iq.consume();
                return;
            }
            if (maybe_params) |params| {
                self.iq.push(impulse_frame, self.idgen.nextId(), params);
            }
        }

        // this is called on both MenuSoundWrapper objects, as well as Wrapper
        // objects (defined in components.zig). the latter has a few more fields
        // which are not used in this function.
        fn paint(self: *@This(), span: zang.Span, out_buf: []f32, tmp_bufs: anytype, sample_rate: f32) void {
            var temps = tmp_bufs[0..ModuleType.num_temps].*;

            comptime {
                // make sure NoteParamsType isn't missing any fields
                for (@typeInfo(ModuleType.Params).Struct.fields) |field| {
                    var found = false;
                    if (std.mem.eql(u8, field.name, "sample_rate")) {
                        found = true;
                    }
                    for (@typeInfo(NoteParamsType).Struct.fields) |note_field| {
                        if (std.mem.eql(u8, field.name, note_field.name)) {
                            found = true;
                        }
                    }
                    if (!found) {
                        @compileError(@typeName(NoteParamsType) ++ ": missing field `" ++ field.name ++ "`");
                    }
                }
            }

            var ctr = self.trigger.counter(span, self.iq.consume());
            while (self.trigger.next(&ctr)) |result| {
                // convert `NoteParams` into `Params`
                var params: ModuleType.Params = undefined;

                inline for (@typeInfo(NoteParamsType).Struct.fields) |field| {
                    @field(params, field.name) = @field(result.params, field.name);
                }
                params.sample_rate = sample_rate;

                self.module.paint(result.span, .{out_buf}, temps, result.note_id_changed, params);
            }
        }
    };
}

// this contains a list of wrappers which parallel the Voice* game components.
fn GameSoundWrapperArray(comptime T: type, comptime component_name_: []const u8) type {
    return struct {
        const component_name = component_name_;
        const count = std.meta.fieldInfo(game.ComponentLists, component_name).field_type.capacity;

        wrappers: [count]GameSoundWrapper(T),

        // can't return @This() here because it can be pretty big (depending on `count`)
        fn init(self: *@This()) void {
            for (self.wrappers) |*wrapper| {
                wrapper.* = GameSoundWrapper(T).init();
            }
        }

        fn sync(self: *@This(), reset: bool, loaded_samples: *const LoadedSamples, impulse_frame: usize, component_list: anytype) void {
            for (self.wrappers) |*wrapper, i| {
                if (component_list.id[i] == 0) {
                    continue;
                }
                if (T == zang.Sampler) {
                    const maybe_params: ?SamplerNoteParams = if (component_list.data[i].sample) |sample|
                        .{ .sample = loaded_samples.get(sample), .channel = 0, .loop = false }
                    else
                        null;
                    wrapper.sync(reset, impulse_frame, maybe_params);
                    component_list.data[i].sample = null;
                } else {
                    wrapper.sync(reset, impulse_frame, component_list.data[i].params);
                    component_list.data[i].params = null;
                }
            }
        }

        fn paint(self: *@This(), span: zang.Span, out_buf: anytype, tmp_bufs: anytype, sample_rate: f32) void {
            for (self.wrappers) |*wrapper| {
                wrapper.paint(span, out_buf, tmp_bufs, sample_rate);
            }
        }
    };
}

// see https://github.com/ziglang/zig/issues/5479
const VoiceAccelerateWrapperArray = GameSoundWrapperArray(AccelerateVoice, "VoiceAccelerate");
const VoiceCoinWrapperArray = GameSoundWrapperArray(CoinVoice, "VoiceCoin");
const VoiceExplosionWrapperArray = GameSoundWrapperArray(ExplosionVoice, "VoiceExplosion");
const VoiceLaserWrapperArray = GameSoundWrapperArray(LaserVoice, "VoiceLaser");
const VoicePowerUpWrapperArray = GameSoundWrapperArray(PowerUpVoice, "VoicePowerUp");
const VoiceSamplerWrapperArray = GameSoundWrapperArray(zang.Sampler, "VoiceSampler");
const VoiceWaveBeginWrapperArray = GameSoundWrapperArray(WaveBeginVoice, "VoiceWaveBegin");

pub const MainModule = struct {
    menu_backoff: GameSoundWrapper(MenuBackoffVoice),
    menu_blip: GameSoundWrapper(MenuBlipVoice),
    menu_ding: GameSoundWrapper(MenuDingVoice),

    voice_accelerate: VoiceAccelerateWrapperArray,
    voice_coin: VoiceCoinWrapperArray,
    voice_explosion: VoiceExplosionWrapperArray,
    voice_laser: VoiceLaserWrapperArray,
    voice_power_up: VoicePowerUpWrapperArray,
    voice_sampler: VoiceSamplerWrapperArray,
    voice_wave_begin: VoiceWaveBeginWrapperArray,

    loaded_samples: LoadedSamples,

    out_buf: []f32,
    // this will fail to compile if there aren't enough temp bufs to supply
    // each of the sound module types being used
    // TODO automatically determine this by looking at all the modules
    tmp_bufs: [4][]f32,

    // these fields are owned by the audio thread. they are set in sync and
    // used in the audio callback
    volume: u32,
    sample_rate: f32,

    // call this in the main thread before the audio device is set up
    pub fn init(self: *MainModule, hunk: *Hunk, volume: u32, sample_rate: f32, audio_buffer_size: usize) !void {
        self.menu_backoff = GameSoundWrapper(MenuBackoffVoice).init();
        self.menu_blip = GameSoundWrapper(MenuBlipVoice).init();
        self.menu_ding = GameSoundWrapper(MenuDingVoice).init();
        VoiceAccelerateWrapperArray.init(&self.voice_accelerate);
        VoiceCoinWrapperArray.init(&self.voice_coin);
        VoiceExplosionWrapperArray.init(&self.voice_explosion);
        VoiceLaserWrapperArray.init(&self.voice_laser);
        VoicePowerUpWrapperArray.init(&self.voice_power_up);
        VoiceSamplerWrapperArray.init(&self.voice_sampler);
        VoiceWaveBeginWrapperArray.init(&self.voice_wave_begin);
        // these allocations are never freed (but it's ok because this
        // object is created once in the main function)
        self.loaded_samples = try LoadedSamples.init(hunk);
        self.out_buf = try hunk.low().allocator.alloc(f32, audio_buffer_size);
        self.tmp_bufs = .{
            try hunk.low().allocator.alloc(f32, audio_buffer_size),
            try hunk.low().allocator.alloc(f32, audio_buffer_size),
            try hunk.low().allocator.alloc(f32, audio_buffer_size),
            try hunk.low().allocator.alloc(f32, audio_buffer_size),
        };
        self.volume = volume;
        self.sample_rate = sample_rate;
    }

    // called when audio thread is locked. this is where we communicate
    // information from the main thread to the audio thread.
    pub fn sync(self: *MainModule, reset: bool, volume: u32, sample_rate: f32, gs: *game.Session, menu_sounds: *MenuSounds) void {
        const impulse_frame: usize = 0;

        self.volume = volume;
        self.sample_rate = sample_rate;

        inline for (@typeInfo(MainModule).Struct.fields) |field| {
            if (comptime std.mem.startsWith(u8, field.name, "menu_")) {
                const maybe_params_ptr = &@field(menu_sounds, field.name[5..]);
                @field(self, field.name).sync(reset, impulse_frame, maybe_params_ptr.*);
                maybe_params_ptr.* = null;
            }
            if (comptime std.mem.startsWith(u8, field.name, "voice_")) {
                const component_name = @TypeOf(@field(self, field.name)).component_name;
                const component_list = &@field(gs.ecs.components, component_name);
                @field(self, field.name).sync(reset, &self.loaded_samples, impulse_frame, component_list);
            }
        }
    }

    // called in the audio thread
    pub fn paint(self: *MainModule) []f32 {
        const span = zang.Span.init(0, self.out_buf.len);

        zang.zero(span, self.out_buf);

        inline for (@typeInfo(MainModule).Struct.fields) |field| {
            if (comptime std.mem.startsWith(u8, field.name, "menu_") or
                comptime std.mem.startsWith(u8, field.name, "voice_"))
            {
                @field(self, field.name).paint(span, self.out_buf, self.tmp_bufs, self.sample_rate);
            }
        }

        return self.out_buf;
    }
};
