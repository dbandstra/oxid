const build_options = @import("build_options");
const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
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

pub const SamplerNoteParams = struct {
    wav: zang.WavContents,
    loop: bool,
};

pub const MainModule = struct {
    initialized: bool,

    drop_web: zang.WavContents,
    extra_life: zang.WavContents,
    player_scream: zang.WavContents,
    player_death: zang.WavContents,
    player_crumble: zang.WavContents,
    power_up: zang.WavContents,
    monster_impact: zang.WavContents,

    out_buf: []f32,
    // this will fail to compile if there aren't enough temp bufs to supply each
    // of the sound module types being used
    tmp_bufs: [3][]f32,

    // muted: main thread can access this (under lock)
    muted: bool,

    // speed: ditto. if this is 1, play sound at normal rate. if it's 2, play
    // back at double speed, and so on. this is used to speed up the sound when
    // the game is being fast forwarded
    // TODO figure out what happens if it's <= 0. if it breaks, add checks
    speed: f32,

    // call this in the main thread before the audio device is set up
    pub fn init(hunk_side: *HunkSide, audio_buffer_size: usize) !MainModule {
        return MainModule {
            .initialized = true,
            .drop_web = try zang.readWav(@embedFile(build_options.assets_path ++ "/sfx_sounds_interaction5.wav")),
            .extra_life = try zang.readWav(@embedFile(build_options.assets_path ++ "/sfx_sounds_powerup4.wav")),
            .player_scream = try zang.readWav(@embedFile(build_options.assets_path ++ "/sfx_deathscream_human2.wav")),
            .player_death = try zang.readWav(@embedFile(build_options.assets_path ++ "/sfx_exp_cluster7.wav")),
            .player_crumble = try zang.readWav(@embedFile(build_options.assets_path ++ "/sfx_exp_short_soft10.wav")),
            .power_up = try zang.readWav(@embedFile(build_options.assets_path ++ "/sfx_sounds_powerup10.wav")),
            .monster_impact = try zang.readWav(@embedFile(build_options.assets_path ++ "/sfx_sounds_impact1.wav")),
            // these allocations are never freed (but it's ok because this object is
            // create once in the main function)
            .out_buf = try hunk_side.allocator.alloc(f32, audio_buffer_size),
            .tmp_bufs = [3][]f32 {
                try hunk_side.allocator.alloc(f32, audio_buffer_size),
                try hunk_side.allocator.alloc(f32, audio_buffer_size),
                try hunk_side.allocator.alloc(f32, audio_buffer_size),
            },
            .muted = false,
            .speed = 1,
        };
    }

    // called in the audio thread.
    // note: this works under the assumption the thread mutex is locked during
    // the entire audio callback call. this is just how SDL2 works. if we switch
    // to another library that gives more control, this method should be
    // refactored so that all the IQs (impulse queues) are pulled out before
    // painting, so that the thread doesn't need to be locked during the actual
    // painting
    pub fn paint(self: *MainModule, sample_rate: u32, gs: *GameSession) []const f32 {
        const span = zang.Span {
            .start = 0,
            .end = self.out_buf.len,
        };

        zang.zero(span, self.out_buf);

        const mix_freq = @intToFloat(f32, sample_rate) / self.speed;

        var it = gs.iter(c.Voice); while (it.next()) |object| {
            const voice = &object.data;

            switch (voice.wrapper) {
                .Accelerate => |*wrapper| self.paintWrapper(span, wrapper, mix_freq),
                .Coin =>       |*wrapper| self.paintWrapper(span, wrapper, mix_freq),
                .Explosion =>  |*wrapper| self.paintWrapper(span, wrapper, mix_freq),
                .Laser =>      |*wrapper| self.paintWrapper(span, wrapper, mix_freq),
                .MenuBackoff =>|*wrapper| self.paintWrapper(span, wrapper, mix_freq),
                .MenuBlip =>   |*wrapper| self.paintWrapper(span, wrapper, mix_freq),
                .MenuDing =>   |*wrapper| self.paintWrapper(span, wrapper, mix_freq),
                .Sample =>     |*wrapper| self.paintWrapper(span, wrapper, mix_freq),
                .WaveBegin =>  |*wrapper| self.paintWrapper(span, wrapper, mix_freq),
                else => {},
            }
        }

        if (self.muted) {
            zang.zero(span, self.out_buf);
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

        var ctr = wrapper.trigger.counter(span, wrapper.iq.consume());
        while (wrapper.trigger.next(&ctr)) |result| {
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

                        wrapper.initial_sample = null;
                        wrapper.iq.push(impulse_frame, SamplerNoteParams {
                            .loop = false,
                            .wav = switch (sample) {
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
        wrapper.iq.push(impulse_frame, params);
        wrapper.initial_params = null;
    }
}
