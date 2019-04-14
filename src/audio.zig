const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const zang = @import("zang");
const CoinVoice = @import("audio/coin.zig").CoinVoice;
const ExplosionVoice = @import("audio/explosion.zig").ExplosionVoice;
const LaserVoice = @import("audio/laser.zig").LaserVoice;
const SampleVoice = @import("audio/sample.zig").SampleVoice;

// TODO - can i get rid of this and just refer to the impulse queues directly?
// only problem is that sounds are played directly through component middleware
pub const Sample = enum{
  Accelerate,
  Coin,
  DropWeb,
  ExtraLife,
  PlayerShot,
  PlayerScream,
  PlayerDeath,
  PlayerCrumble,
  PowerUp,
  MonsterImpact,
  MonsterShot,
  MonsterDeath,
  WaveBegin,
};

pub const MainModule = struct {
  frame_index: usize,
  r: std.rand.Xoroshiro128,
  buf0: []f32,
  buf1: []f32,
  buf2: []f32,
  buf3: []f32,

  // muted: main thread can access this (under lock)
  muted: bool,

  // speed: ditto. if this is 1, play sound at normal rate. if it's 2, play
  // back at double speed, and so on. this is used to speed up the sound when
  // the game is being fast forwarded
  speed: u32,

  coin: CoinVoice,
  drop_web: SampleVoice,
  extra_life: SampleVoice,
  player_shot: LaserVoice,
  player_scream: SampleVoice,
  player_death: SampleVoice,
  player_crumble: SampleVoice,
  power_up: SampleVoice,
  monster_impact: SampleVoice,
  monster_shot: SampleVoice,
  monster_death: ExplosionVoice,
  wave_begin: SampleVoice,

  // call this in the main thread before the audio device is set up
  pub fn init(hunk_side: *HunkSide, comptime sample_rate: u32, audio_buffer_size: usize) !MainModule {
    return MainModule {
      .frame_index = 0,
      .r = std.rand.DefaultPrng.init(0),
      // these allocations are never freed (but it's ok because this object is
      // create once in the main function)
      .buf0 = try hunk_side.allocator.alloc(f32, audio_buffer_size),
      .buf1 = try hunk_side.allocator.alloc(f32, audio_buffer_size),
      .buf2 = try hunk_side.allocator.alloc(f32, audio_buffer_size),
      .buf3 = try hunk_side.allocator.alloc(f32, audio_buffer_size),
      .muted = false,
      .speed = 1,
      .coin = CoinVoice.init(sample_rate),
      .drop_web = try SampleVoice.init("sfx_sounds_interaction5.wav"),
      .extra_life = try SampleVoice.init("sfx_sounds_powerup4.wav"),
      .player_shot = LaserVoice.init(sample_rate, 2.0, 0.5, 0.5),
      .player_scream = try SampleVoice.init("sfx_deathscream_human2.wav"),
      .player_death = try SampleVoice.init("sfx_exp_cluster7.wav"),
      .player_crumble = try SampleVoice.init("sfx_exp_short_soft10.wav"),
      .power_up = try SampleVoice.init("sfx_sounds_powerup10.wav"),
      .monster_impact = try SampleVoice.init("sfx_sounds_impact1.wav"),
      .monster_shot = try SampleVoice.init("sfx_wpn_laser10.wav"),
      .monster_death = ExplosionVoice.init(sample_rate),
      .wave_begin = try SampleVoice.init("sfx_sound_mechanicalnoise2.wav"),
    };
  }

  // call this in the main thread with the audio device locked
  pub fn playSample(self: *MainModule, sample: Sample) void {
    const maybe_iq = switch (sample) {
      .Accelerate => null, // TODO
      .Coin => &self.coin.base.iq,
      .DropWeb => &self.drop_web.iq,
      .ExtraLife => &self.extra_life.iq,
      .PlayerShot => &self.player_shot.base.iq,
      .PlayerScream => &self.player_scream.iq,
      .PlayerDeath => &self.player_death.iq,
      .PlayerCrumble => &self.player_crumble.iq,
      .PowerUp => &self.power_up.iq,
      .MonsterImpact => &self.monster_impact.iq,
      .MonsterShot => &self.monster_shot.iq,
      .MonsterDeath => &self.monster_death.base.iq,
      .WaveBegin => &self.wave_begin.iq,
    };

    if (maybe_iq) |iq| {
      // FIXME - impulse_frame being 0 means that sounds will always start
      // playing at the beginning of the mix buffer
      const impulse_frame = 0;

      const variance = 0.1;
      const playback_speed = 1.0 + self.r.random.float(f32) * variance - 0.5 * variance;

      iq.push(impulse_frame, playback_speed, self.frame_index);
    }
  }

  // called in the audio thread.
  // note: this works under the assumption the thread mutex is locked during
  // the entire audio callback call. this is just how SDL2 works. if we switch
  // to another library that gives more control, this method should be
  // refactored so that all the IQs (impulse queues) are pulled out before
  // painting, so that the thread doesn't need to be locked during the actual
  // painting
  pub fn paint(self: *MainModule, sample_rate: u32) []const f32 {
    const out = self.buf0;
    const tmp0 = self.buf1;
    const tmp1 = self.buf2;
    const tmp2 = self.buf3;

    zang.zero(out);

    const mix_freq = sample_rate / self.speed;

    self.coin.base.update(&self.coin, mix_freq, out, [][]f32{tmp0}, self.frame_index);
    self.drop_web.update(mix_freq, out, self.frame_index);
    self.extra_life.update(mix_freq, out, self.frame_index);
    self.player_shot.base.update(&self.player_shot, mix_freq, out, [][]f32{tmp0, tmp1, tmp2}, self.frame_index);
    self.player_scream.update(mix_freq, out, self.frame_index);
    self.player_death.update(mix_freq, out, self.frame_index);
    self.player_crumble.update(mix_freq, out, self.frame_index);
    self.power_up.update(mix_freq, out, self.frame_index);
    self.monster_impact.update(mix_freq, out, self.frame_index);
    self.monster_shot.update(mix_freq, out, self.frame_index);
    self.monster_death.base.update(&self.monster_death, mix_freq, out, [][]f32{tmp0, tmp1, tmp2}, self.frame_index);
    self.wave_begin.update(mix_freq, out, self.frame_index);

    if (self.muted) {
      zang.zero(out);
    }

    self.frame_index += out.len;

    return out;
  }
};
