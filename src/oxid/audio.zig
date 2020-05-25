const builtin = @import("builtin");
const build_options = @import("build_options");
const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
const wav = @import("zig-wav");
const zang = @import("zang");
const GameSession = @import("game.zig").GameSession;
const c = @import("components.zig");
const menus = @import("menus.zig");

const MenuBackoffVoice = @import("audio/menu_backoff.zig").MenuBackoffVoice;
const MenuBlipVoice = @import("audio/menu_blip.zig").MenuBlipVoice;
const MenuDingVoice = @import("audio/menu_ding.zig").MenuDingVoice;

pub const AccelerateVoice = @import("audio/accelerate.zig").AccelerateVoice;
pub const CoinVoice = @import("audio/coin.zig").CoinVoice;
pub const ExplosionVoice = @import("audio/explosion.zig").ExplosionVoice;
pub const LaserVoice = @import("audio/laser.zig").LaserVoice;
pub const WaveBeginVoice = @import("audio/wave_begin.zig").WaveBeginVoice;

pub const Sample = enum {
    drop_web,
    extra_life,
    player_scream,
    player_death,
    player_crumble,
    power_up,
    monster_impact,
};

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

fn readWav(hunk: *Hunk, comptime filename: []const u8) !zang.Sample {
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

pub const SamplerNoteParams = struct {
    sample: zang.Sample,
    channel: usize,
    loop: bool,
};

fn MenuSoundWrapper(comptime ModuleType_: type) type {
    return struct {
        const ModuleType = ModuleType_;

        module: ModuleType,
        iq: zang.Notes(ModuleType.NoteParams).ImpulseQueue,
        idgen: zang.IdGenerator,
        trigger: zang.Trigger(ModuleType.NoteParams),

        fn init() @This() {
            return .{
                .module = ModuleType.init(),
                .iq = zang.Notes(ModuleType.NoteParams).ImpulseQueue.init(),
                .idgen = zang.IdGenerator.init(),
                .trigger = zang.Trigger(ModuleType.NoteParams).init(),
            };
        }

        fn push(self: *@This(), params: ModuleType.NoteParams) void {
            const impulse_frame: usize = 0;

            self.iq.push(impulse_frame, self.idgen.nextId(), params);
        }

        fn reset(self: *@This()) void {
            self.iq.length = 0; // FIXME - add a method to zang API for this?
            self.trigger.reset();
        }
    };
}

pub const MainModule = struct {
    menu_backoff: MenuSoundWrapper(MenuBackoffVoice),
    menu_blip: MenuSoundWrapper(MenuBlipVoice),
    menu_ding: MenuSoundWrapper(MenuDingVoice),

    prng: std.rand.DefaultPrng,

    drop_web: zang.Sample,
    extra_life: zang.Sample,
    player_scream: zang.Sample,
    player_death: zang.Sample,
    player_crumble: zang.Sample,
    power_up: zang.Sample,
    monster_impact: zang.Sample,

    out_buf: []f32,
    // this will fail to compile if there aren't enough temp bufs to supply
    // each of the sound module types being used
    tmp_bufs: [3][]f32,

    // call this in the main thread before the audio device is set up
    pub fn init(hunk: *Hunk, audio_buffer_size: usize) !MainModule {
        const rand_seed: u32 = 0;

        return MainModule{
            .menu_backoff = MenuSoundWrapper(MenuBackoffVoice).init(),
            .menu_blip = MenuSoundWrapper(MenuBlipVoice).init(),
            .menu_ding = MenuSoundWrapper(MenuDingVoice).init(),
            .prng = std.rand.DefaultPrng.init(rand_seed),
            .drop_web = try readWav(hunk, "sfx_sounds_interaction5.wav"),
            .extra_life = try readWav(hunk, "sfx_sounds_powerup4.wav"),
            .player_scream = try readWav(hunk, "sfx_deathscream_human2.wav"),
            .player_death = try readWav(hunk, "sfx_exp_cluster7.wav"),
            .player_crumble = try readWav(hunk, "sfx_exp_short_soft10.wav"),
            .power_up = try readWav(hunk, "sfx_sounds_powerup10.wav"),
            .monster_impact = try readWav(hunk, "sfx_sounds_impact1.wav"),
            // these allocations are never freed (but it's ok because this
            // object is created once in the main function)
            .out_buf = try hunk.low().allocator.alloc(f32, audio_buffer_size),
            .tmp_bufs = .{
                try hunk.low().allocator.alloc(f32, audio_buffer_size),
                try hunk.low().allocator.alloc(f32, audio_buffer_size),
                try hunk.low().allocator.alloc(f32, audio_buffer_size),
            },
        };
    }

    // called in the audio thread.
    // note: this works under the assumption the thread mutex is locked during
    // the entire audio callback call. this is just how SDL2 works. if we switch
    // to another library that gives more control, this method should be
    // refactored so that all the IQs (impulse queues) are pulled out before
    // painting, so that the thread doesn't need to be locked during the actual
    // painting
    pub fn paint(self: *MainModule, sample_rate: f32, gs: *GameSession) []f32 {
        const span: zang.Span = .{
            .start = 0,
            .end = self.out_buf.len,
        };

        zang.zero(span, self.out_buf);

        self.paintWrapper(span, &self.menu_backoff, sample_rate);
        self.paintWrapper(span, &self.menu_blip, sample_rate);
        self.paintWrapper(span, &self.menu_ding, sample_rate);

        var it = gs.ecs.componentIter(c.Voice);
        while (it.next()) |voice| {
            switch (voice.wrapper) {
                .accelerate => |*wrapper| self.paintWrapper(span, wrapper, sample_rate),
                .coin => |*wrapper| self.paintWrapper(span, wrapper, sample_rate),
                .explosion => |*wrapper| self.paintWrapper(span, wrapper, sample_rate),
                .laser => |*wrapper| self.paintWrapper(span, wrapper, sample_rate),
                .sample => |*wrapper| self.paintWrapper(span, wrapper, sample_rate),
                .wave_begin => |*wrapper| self.paintWrapper(span, wrapper, sample_rate),
                else => {},
            }
        }

        return self.out_buf;
    }

    // this is called on both MenuSoundWrapper objects, as well as Wrapper
    // objects (defined in components.zig). the latter has a few more fields
    // which are not used in this function.
    fn paintWrapper(self: *MainModule, span: zang.Span, wrapper: var, sample_rate: f32) void {
        std.debug.assert(@typeInfo(@TypeOf(wrapper)) == .Pointer);
        const ModuleType = @typeInfo(@TypeOf(wrapper)).Pointer.child.ModuleType;
        var temps: [ModuleType.num_temps][]f32 = undefined;
        comptime var i: usize = 0;
        inline while (i < ModuleType.num_temps) : (i += 1) {
            temps[i] = self.tmp_bufs[i];
        }

        const NoteParamsType = if (ModuleType == zang.Sampler)
            SamplerNoteParams
        else
            ModuleType.NoteParams;

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

        var ctr = wrapper.trigger.counter(span, wrapper.iq.consume());
        while (wrapper.trigger.next(&ctr)) |result| {
            // convert `NoteParams` into `Params`
            var params: ModuleType.Params = undefined;

            inline for (@typeInfo(NoteParamsType).Struct.fields) |field| {
                @field(params, field.name) = @field(result.params, field.name);
            }
            params.sample_rate = sample_rate;

            wrapper.module.paint(result.span, .{self.out_buf}, temps, result.note_id_changed, params);
        }
    }

    // called in the main thread
    pub fn playMenuSound(self: *MainModule, sound: menus.Sound) void {
        switch (sound) {
            .backoff => {
                self.menu_backoff.push(.{});
            },
            .blip => {
                const rand = &self.prng.random;
                self.menu_blip.push(.{ .freq_mul = 0.95 + 0.1 * rand.float(f32) });
            },
            .ding => {
                self.menu_ding.push(.{});
            },
        }
    }

    pub fn resetMenuSounds(self: *MainModule) void {
        self.menu_backoff.reset();
        self.menu_blip.reset();
        self.menu_ding.reset();
    }

    // called in the main thread
    pub fn playSounds(self: *MainModule, gs: *GameSession, impulse_frame: usize) void {
        var it = gs.ecs.componentIter(c.Voice);
        while (it.next()) |object| {
            switch (object.wrapper) {
                .accelerate => |*wrapper| updateVoice(wrapper, impulse_frame),
                .coin => |*wrapper| updateVoice(wrapper, impulse_frame),
                .explosion => |*wrapper| updateVoice(wrapper, impulse_frame),
                .laser => |*wrapper| updateVoice(wrapper, impulse_frame),
                .wave_begin => |*wrapper| updateVoice(wrapper, impulse_frame),
                .sample => |*wrapper| {
                    if (wrapper.initial_sample) |sample| {
                        wrapper.iq.push(impulse_frame, wrapper.idgen.nextId(), .{
                            .loop = false,
                            .channel = 0,
                            .sample = switch (sample) {
                                .drop_web => self.drop_web,
                                .extra_life => self.extra_life,
                                .player_scream => self.player_scream,
                                .player_death => self.player_death,
                                .player_crumble => self.player_crumble,
                                .power_up => self.power_up,
                                .monster_impact => self.monster_impact,
                            },
                        });
                        wrapper.initial_sample = null;
                    }
                },
            }
        }
    }
};

fn updateVoice(wrapper: var, impulse_frame: usize) void {
    if (wrapper.initial_params) |params| {
        wrapper.iq.push(impulse_frame, wrapper.idgen.nextId(), params);
        wrapper.initial_params = null;
    }
}
