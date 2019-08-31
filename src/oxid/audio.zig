const builtin = @import("builtin");
const build_options = @import("build_options");
const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const wav = @import("zig-wav");
const zang = @import("zang");
const GameSession = @import("game.zig").GameSession;
const c = @import("components.zig");

pub const AccelerateVoice = @import("audio/accelerate.zig").AccelerateVoice;
pub const CoinVoice = @import("audio/coin.zig").CoinVoice;
pub const ExplosionVoice = @import("audio/explosion.zig").ExplosionVoice;
pub const LaserVoice = @import("audio/laser.zig").LaserVoice;
pub const MenuBackoffVoice = @import("audio/menu_backoff.zig").MenuBackoffVoice;
pub const MenuBlipVoice = @import("audio/menu_blip.zig").MenuBlipVoice;
pub const MenuDingVoice = @import("audio/menu_ding.zig").MenuDingVoice;
pub const WaveBeginVoice = @import("audio/wave_begin.zig").WaveBeginVoice;

pub const Sample = enum {
    DropWeb,
    ExtraLife,
    PlayerScream,
    PlayerDeath,
    PlayerCrumble,
    PowerUp,
    MonsterImpact,
};

fn readWav(comptime filename: []const u8) !zang.Sample {
    const buf = @embedFile(build_options.assets_path ++ "/" ++ filename);
    var sis = std.io.SliceInStream.init(buf);
    const stream = &sis.stream;

    const verbose = builtin.arch != .wasm32; // wasm doesn't have stderr
    const Loader = wav.Loader(std.io.SliceInStream.Error, verbose);
    const preloaded = try Loader.preload(stream);

    // don't call Loader.load because we're working on a slice, so we can just
    // take a subslice of it
    return zang.Sample {
        .num_channels = preloaded.num_channels,
        .sample_rate = preloaded.sample_rate,
        .format = switch (preloaded.format) {
            .U8 => zang.SampleFormat.U8,
            .S16LSB => zang.SampleFormat.S16LSB,
            .S24LSB => zang.SampleFormat.S24LSB,
            .S32LSB => zang.SampleFormat.S32LSB,
        },
        .data = buf[sis.pos .. sis.pos + preloaded.getNumBytes()],
    };
}

pub const SamplerNoteParams = struct {
    sample: zang.Sample,
    channel: usize,
    loop: bool,
};

pub const MainModule = struct {
    initialized: bool,

    drop_web: zang.Sample,
    extra_life: zang.Sample,
    player_scream: zang.Sample,
    player_death: zang.Sample,
    player_crumble: zang.Sample,
    power_up: zang.Sample,
    monster_impact: zang.Sample,

    out_buf: []f32,
    // this will fail to compile if there aren't enough temp bufs to supply each
    // of the sound module types being used
    tmp_bufs: [3][]f32,

    // call this in the main thread before the audio device is set up
    pub fn init(hunk_side: *HunkSide, audio_buffer_size: usize) !MainModule {
        return MainModule {
            .initialized = true,
            .drop_web = try readWav("sfx_sounds_interaction5.wav"),
            .extra_life = try readWav("sfx_sounds_powerup4.wav"),
            .player_scream = try readWav("sfx_deathscream_human2.wav"),
            .player_death = try readWav("sfx_exp_cluster7.wav"),
            .player_crumble = try readWav("sfx_exp_short_soft10.wav"),
            .power_up = try readWav("sfx_sounds_powerup10.wav"),
            .monster_impact = try readWav("sfx_sounds_impact1.wav"),
            // these allocations are never freed (but it's ok because this object is
            // create once in the main function)
            .out_buf = try hunk_side.allocator.alloc(f32, audio_buffer_size),
            .tmp_bufs = [3][]f32 {
                try hunk_side.allocator.alloc(f32, audio_buffer_size),
                try hunk_side.allocator.alloc(f32, audio_buffer_size),
                try hunk_side.allocator.alloc(f32, audio_buffer_size),
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
    pub fn paint(self: *MainModule, sample_rate: f32, gs: *GameSession) []const f32 {
        const span = zang.Span {
            .start = 0,
            .end = self.out_buf.len,
        };

        zang.zero(span, self.out_buf);

        var it = gs.iter(c.Voice); while (it.next()) |object| {
            const voice = &object.data;

            switch (voice.wrapper) {
                .Accelerate => |*wrapper| self.paintWrapper(span, wrapper, sample_rate),
                .Coin =>       |*wrapper| self.paintWrapper(span, wrapper, sample_rate),
                .Explosion =>  |*wrapper| self.paintWrapper(span, wrapper, sample_rate),
                .Laser =>      |*wrapper| self.paintWrapper(span, wrapper, sample_rate),
                .MenuBackoff =>|*wrapper| self.paintWrapper(span, wrapper, sample_rate),
                .MenuBlip =>   |*wrapper| self.paintWrapper(span, wrapper, sample_rate),
                .MenuDing =>   |*wrapper| self.paintWrapper(span, wrapper, sample_rate),
                .Sample =>     |*wrapper| self.paintWrapper(span, wrapper, sample_rate),
                .WaveBegin =>  |*wrapper| self.paintWrapper(span, wrapper, sample_rate),
                else => {},
            }
        }

        return self.out_buf;
    }

    fn paintWrapper(self: *MainModule, span: zang.Span, wrapper: var, sample_rate: f32) void {
        std.debug.assert(@typeId(@typeOf(wrapper)) == .Pointer);
        const ModuleType = @typeInfo(@typeOf(wrapper)).Pointer.child.ModuleType;
        var temps: [ModuleType.num_temps][]f32 = undefined;
        var i: usize = 0; while (i < ModuleType.num_temps) : (i += 1) {
            temps[i] = self.tmp_bufs[i];
        }

        const NoteParamsType =
            if (ModuleType == zang.Sampler)
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

            wrapper.module.paint(result.span, [1][]f32{self.out_buf}, temps, result.note_id_changed, params);
        }
    }

    // called in the main thread
    pub fn playSounds(self: *MainModule, gs: *GameSession, impulse_frame: usize) void {
        var it = gs.iter(c.Voice); while (it.next()) |object| {
            switch (object.data.wrapper) {
                .Accelerate => |*wrapper| updateVoice(wrapper, impulse_frame),
                .Coin =>       |*wrapper| updateVoice(wrapper, impulse_frame),
                .Explosion =>  |*wrapper| updateVoice(wrapper, impulse_frame),
                .Laser =>      |*wrapper| updateVoice(wrapper, impulse_frame),
                .MenuBackoff =>|*wrapper| updateVoice(wrapper, impulse_frame),
                .MenuBlip =>   |*wrapper| updateVoice(wrapper, impulse_frame),
                .MenuDing =>   |*wrapper| updateVoice(wrapper, impulse_frame),
                .WaveBegin =>  |*wrapper| updateVoice(wrapper, impulse_frame),
                .Sample =>     |*wrapper| {
                    if (wrapper.initial_sample) |sample_alias| {
                        // https://github.com/ziglang/zig/issues/2915
                        const sample = sample_alias;

                        wrapper.initial_sample = null; // this invalidates sample_alias
                        wrapper.iq.push(impulse_frame, wrapper.idgen.nextId(), SamplerNoteParams {
                            .loop = false,
                            .channel = 0,
                            .sample = switch (sample) {
                                .DropWeb => self.drop_web,
                                .ExtraLife => self.extra_life,
                                .PlayerScream => self.player_scream,
                                .PlayerDeath => self.player_death,
                                .PlayerCrumble => self.player_crumble,
                                .PowerUp => self.power_up,
                                .MonsterImpact => self.monster_impact,
                            },
                        });
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
