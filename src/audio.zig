const build_options = @import("build_options");
const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const zang = @import("zang");
const GameSession = @import("game.zig").GameSession;

// FIXME - i need some kind of basic resource manager.
// right now, game code only has access to GameSession, which is the ECS and nothing else.
// there's currently no way to get these loaded sounds to the game code, except by a global...
pub const Samples = struct {
  drop_web: zang.WavContents,
  extra_life: zang.WavContents,
  player_scream: zang.WavContents,
  player_death: zang.WavContents,
  player_crumble: zang.WavContents,
  power_up: zang.WavContents,
  monster_impact: zang.WavContents,
  monster_shot: zang.WavContents,
};

// hax!!!! (see above)
pub var samples: Samples = undefined;

pub const MainModule = struct {
  initialized: bool,
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
    samples.drop_web = try zang.readWav(@embedFile(build_options.assets_path ++ "/sfx_sounds_interaction5.wav"));
    samples.extra_life = try zang.readWav(@embedFile(build_options.assets_path ++ "/sfx_sounds_powerup4.wav"));
    samples.player_scream = try zang.readWav(@embedFile(build_options.assets_path ++ "/sfx_deathscream_human2.wav"));
    samples.player_death = try zang.readWav(@embedFile(build_options.assets_path ++ "/sfx_exp_cluster7.wav"));
    samples.player_crumble = try zang.readWav(@embedFile(build_options.assets_path ++ "/sfx_exp_short_soft10.wav"));
    samples.power_up = try zang.readWav(@embedFile(build_options.assets_path ++ "/sfx_sounds_powerup10.wav"));
    samples.monster_impact = try zang.readWav(@embedFile(build_options.assets_path ++ "/sfx_sounds_impact1.wav"));
    samples.monster_shot = try zang.readWav(@embedFile(build_options.assets_path ++ "/sfx_wpn_laser10.wav"));

    return MainModule {
      .initialized = true,
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
    zang.zero(self.out_buf);

    const mix_freq = @intToFloat(f32, sample_rate) / self.speed;

    inline for (@typeInfo(GameSession.ComponentListsType).Struct.fields) |field| {
      const ComponentType = field.field_type.ComponentType;
      inline for (@typeInfo(ComponentType).Struct.fields) |component_field| {
        if (comptime std.mem.eql(u8, component_field.name, "iq")) {
          var tmp: [ComponentType.NumTempBufs][]f32 = undefined;
          comptime var i: usize = 0;
          inline while (i < ComponentType.NumTempBufs) : (i += 1) {
            tmp[i] = self.tmp_bufs[i];
          }
          var it = gs.iter(ComponentType); while (it.next()) |object| {
            object.data.trigger.paintFromImpulses(
              &object.data,
              mix_freq,
              self.out_buf,
              object.data.iq.consume(),
              tmp,
            );
          }
        }
      }
    }

    if (self.muted) {
      zang.zero(self.out_buf);
    }

    return self.out_buf;
  }
};
