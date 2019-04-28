const build_options = @import("build_options");
const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const zang = @import("zang");
const GameSession = @import("game.zig").GameSession;
const C = @import("components.zig");

pub const Sample = enum {
  DropWeb,
  ExtraLife,
  PlayerScream,
  PlayerDeath,
  PlayerCrumble,
  PowerUp,
  MonsterImpact,
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

  pub fn getSampleParams(self: *MainModule, sample: Sample) zang.Sampler.Params {
    const wav = switch (sample) {
      .DropWeb => self.drop_web,
      .ExtraLife => self.extra_life,
      .PlayerScream => self.player_scream,
      .PlayerDeath => self.player_death,
      .PlayerCrumble => self.player_crumble,
      .PowerUp => self.power_up,
      .MonsterImpact => self.monster_impact,
    };

    return zang.Sampler.Params {
      .freq = 1.0,
      .sample_data = wav.data,
      .sample_rate = @intToFloat(f32, wav.sample_rate),
      .sample_freq = null,
      .loop = false,
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
    zang.zero(self.out_buf);

    const mix_freq = @intToFloat(f32, sample_rate) / self.speed;

    var it = gs.iter(C.Voices); while (it.next()) |object| {
      const voices = &object.data;

      if (voices.accelerate) |*wrapper| self.paintWrapper(wrapper, mix_freq);
      if (voices.coin)       |*wrapper| self.paintWrapper(wrapper, mix_freq);
      if (voices.explosion)  |*wrapper| self.paintWrapper(wrapper, mix_freq);
      if (voices.laser)      |*wrapper| self.paintWrapper(wrapper, mix_freq);
      if (voices.sample)     |*wrapper| self.paintWrapper(wrapper, mix_freq);
      if (voices.wave_begin) |*wrapper| self.paintWrapper(wrapper, mix_freq);
    }

    if (self.muted) {
      zang.zero(self.out_buf);
    }

    return self.out_buf;
  }

  fn paintWrapper(self: *MainModule, wrapper: var, sample_rate: f32) void {
    std.debug.assert(@typeId(@typeOf(wrapper)) == .Pointer);
    const ModuleType = @typeInfo(@typeOf(wrapper)).Pointer.child.ModuleType;
    var temps: [ModuleType.NumTemps][]f32 = undefined;
    var i: usize = 0; while (i < ModuleType.NumTemps) : (i += 1) {
      temps[i] = self.tmp_bufs[i];
    }
    wrapper.module.paintFromImpulses(sample_rate, [1][]f32{self.out_buf}, [0][]f32{}, temps, wrapper.iq.consume());
  }
};
