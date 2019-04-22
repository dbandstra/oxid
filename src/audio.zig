const build_options = @import("build_options");
const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const zang = @import("zang");
const AccelerateVoice = @import("audio/accelerate.zig").AccelerateVoice;
const CoinVoice = @import("audio/coin.zig").CoinVoice;
const ExplosionVoice = @import("audio/explosion.zig").ExplosionVoice;
const LaserVoice = @import("audio/laser.zig").LaserVoice;
const WaveBeginVoice = @import("audio/wave_begin.zig").WaveBeginVoice;

pub const Sample = enum {
  Accelerate1,
  Accelerate2,
  Accelerate3,
  Accelerate4,
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

// `Voice`: convenience wrapper for:
// - impulse queue (the "inbox" which you push to in order to trigger sound effects)
// - module (the actual sound module being used)
// - trigger (calls into module's paint method using the impulses in the impulse queue)
pub fn Voice(comptime ModuleType: type) type {
  return struct {
    iq: zang.ImpulseQueue,
    module: ModuleType,
    trigger: zang.Trigger(ModuleType),

    pub fn init(module: ModuleType) @This() {
      return @This() {
        .iq = zang.ImpulseQueue.init(),
        .module = module,
        .trigger = zang.Trigger(ModuleType).init(),
      };
    }

    pub fn paint(self: *@This(), sample_rate: f32, out: []f32, tmp: [ModuleType.NumTempBufs][]f32) void {
      self.trigger.paintFromImpulses(&self.module, sample_rate, out, self.iq.consume(), tmp);
    }
  };
}

fn loadSampler(comptime filename: []const u8) !zang.Sampler {
  const wav = try zang.readWav(@embedFile(build_options.assets_path ++ "/" ++ filename));

  return zang.Sampler.init(wav.data, @intToFloat(f32, wav.sample_rate), 1.0);
}

pub const MainModule = struct {
  initialized: bool,
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
  // TODO figure out what happens if it's <= 0. if it breaks, add checks
  speed: f32,

  accelerate: Voice(AccelerateVoice),
  coin: Voice(CoinVoice),
  drop_web: Voice(zang.Sampler),
  extra_life: Voice(zang.Sampler),
  player_shot: Voice(LaserVoice),
  player_scream: Voice(zang.Sampler),
  player_death: Voice(zang.Sampler),
  player_crumble: Voice(zang.Sampler),
  power_up: Voice(zang.Sampler),
  monster_impact: Voice(zang.Sampler),
  monster_shot: Voice(zang.Sampler),
  monster_death: Voice(ExplosionVoice),
  wave_begin: Voice(WaveBeginVoice),

  // call this in the main thread before the audio device is set up
  pub fn init(hunk_side: *HunkSide, audio_buffer_size: usize) !MainModule {
    return MainModule {
      .initialized = true,
      .r = std.rand.DefaultPrng.init(0),
      // these allocations are never freed (but it's ok because this object is
      // create once in the main function)
      .buf0 = try hunk_side.allocator.alloc(f32, audio_buffer_size),
      .buf1 = try hunk_side.allocator.alloc(f32, audio_buffer_size),
      .buf2 = try hunk_side.allocator.alloc(f32, audio_buffer_size),
      .buf3 = try hunk_side.allocator.alloc(f32, audio_buffer_size),
      .muted = false,
      .speed = 1,
      .accelerate = Voice(AccelerateVoice).init(AccelerateVoice.init()),
      .coin = Voice(CoinVoice).init(CoinVoice.init()),
      .drop_web = Voice(zang.Sampler).init(try loadSampler("sfx_sounds_interaction5.wav")),
      .extra_life = Voice(zang.Sampler).init(try loadSampler("sfx_sounds_powerup4.wav")),
      .player_shot = Voice(LaserVoice).init(LaserVoice.init(2.0, 0.5, 0.5)),
      .player_scream = Voice(zang.Sampler).init(try loadSampler("sfx_deathscream_human2.wav")),
      .player_death = Voice(zang.Sampler).init(try loadSampler("sfx_exp_cluster7.wav")),
      .player_crumble = Voice(zang.Sampler).init(try loadSampler("sfx_exp_short_soft10.wav")),
      .power_up = Voice(zang.Sampler).init(try loadSampler("sfx_sounds_powerup10.wav")),
      .monster_impact = Voice(zang.Sampler).init(try loadSampler("sfx_sounds_impact1.wav")),
      .monster_shot = Voice(zang.Sampler).init(try loadSampler("sfx_wpn_laser10.wav")),
      .monster_death = Voice(ExplosionVoice).init(ExplosionVoice.init()),
      .wave_begin = Voice(WaveBeginVoice).init(WaveBeginVoice.init()),
    };
  }

  // call this in the main thread with the audio device locked
  pub fn playSample(self: *MainModule, sample: Sample) void {
    // FIXME - impulse_frame being 0 means that sounds will always start
    // playing at the beginning of the mix buffer
    const impulse_frame = 0;

    const iq = switch (sample) {
      .Accelerate1 => { self.accelerate.iq.push(impulse_frame, 1.25); return; },
      .Accelerate2 => { self.accelerate.iq.push(impulse_frame, 1.5); return; },
      .Accelerate3 => { self.accelerate.iq.push(impulse_frame, 1.75); return; },
      .Accelerate4 => { self.accelerate.iq.push(impulse_frame, 2.0); return; },
      .Coin => &self.coin.iq,
      .DropWeb => &self.drop_web.iq,
      .ExtraLife => &self.extra_life.iq,
      .PlayerShot => &self.player_shot.iq,
      .PlayerScream => &self.player_scream.iq,
      .PlayerDeath => &self.player_death.iq,
      .PlayerCrumble => &self.player_crumble.iq,
      .PowerUp => &self.power_up.iq,
      .MonsterImpact => &self.monster_impact.iq,
      .MonsterShot => &self.monster_shot.iq,
      .MonsterDeath => &self.monster_death.iq,
      .WaveBegin => &self.wave_begin.iq,
    };

    const variance = 0.1;
    const playback_speed = 1.0 + self.r.random.float(f32) * variance - 0.5 * variance;

    iq.push(impulse_frame, playback_speed);
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

    const mix_freq = @intToFloat(f32, sample_rate) / self.speed;

    // TODO these voices should be in components and belong to the entities
    self.accelerate.paint(mix_freq, out, [][]f32{tmp0, tmp1});
    self.coin.paint(mix_freq, out, [][]f32{tmp0, tmp1});
    self.drop_web.paint(mix_freq, out, [][]f32{});
    self.extra_life.paint(mix_freq, out, [][]f32{});
    self.player_shot.paint(mix_freq, out, [][]f32{tmp0, tmp1, tmp2});
    self.player_scream.paint(mix_freq, out, [][]f32{});
    self.player_death.paint(mix_freq, out, [][]f32{});
    self.player_crumble.paint(mix_freq, out, [][]f32{});
    self.power_up.paint(mix_freq, out, [][]f32{});
    self.monster_impact.paint(mix_freq, out, [][]f32{});
    self.monster_shot.paint(mix_freq, out, [][]f32{});
    self.monster_death.paint(mix_freq, out, [][]f32{tmp0, tmp1, tmp2});
    self.wave_begin.paint(mix_freq, out, [][]f32{tmp0, tmp1});

    if (self.muted) {
      zang.zero(out);
    }

    return out;
  }
};
