const build_options = @import("build_options");
const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const zang = @import("zang");
const PlatformAudioState = @import("common/platform/audio.zig").AudioState;

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

const SampleVoice = struct {
  iq: zang.ImpulseQueue,
  sampler: zang.Sampler,

  fn init(comptime filename: []const u8) !SampleVoice {
    var rate: u32 = undefined;

    const data = try zang.readWav(@embedFile(build_options.assets_path ++ "/" ++ filename), &rate);

    return SampleVoice{
      .iq = zang.ImpulseQueue.init(),
      .sampler = zang.Sampler.init(data, rate, 1.0),
    };
  }

  fn update(self: *SampleVoice, sample_rate: u32, out: []f32, frame_index: usize) void {
    if (!self.iq.isEmpty()) {
      self.sampler.paintFromImpulses(sample_rate, out, self.iq.getImpulses(), frame_index);
    }

    self.iq.flush(frame_index, out.len);
  }
};

// expects ModuleType to have `paint` method
fn VoiceBase(comptime ModuleType: type, comptime num_temp_bufs: usize) type {
  return struct {
    iq: zang.ImpulseQueue,
    sub_frame_index: usize,
    note_id: usize,
    freq: f32,

    fn init() @This() {
      return @This() {
        .iq = zang.ImpulseQueue.init(),
        .sub_frame_index = 0,
        .note_id = 0,
        .freq = 0.0,
      };
    }

    fn update(
      base: *@This(),
      module: *ModuleType,
      sample_rate: u32,
      out: []f32,
      tmp_bufs: [num_temp_bufs][]f32,
      frame_index: usize,
    ) void {
      var i: usize = 0;
      while (i < num_temp_bufs) : (i += 1) {
        std.debug.assert(out.len == tmp_bufs[i].len);
      }

      if (!base.iq.isEmpty()) {
        const track = base.iq.getImpulses();

        var start: usize = 0;

        while (start < out.len) {
          const note_span = zang.getNextNoteSpan(track, frame_index, start, out.len);

          std.debug.assert(note_span.start == start);
          std.debug.assert(note_span.end > start);
          std.debug.assert(note_span.end <= out.len);

          const buf_span = out[note_span.start .. note_span.end];
          var tmp_spans: [num_temp_bufs][]f32 = undefined;
          comptime var ci: usize = 0;
          comptime while (ci < num_temp_bufs) : (ci += 1) {
            tmp_spans[ci] = tmp_bufs[ci][note_span.start .. note_span.end];
          };

          if (note_span.note) |note| {
            if (note.id != base.note_id) {
              std.debug.assert(note.id > base.note_id);

              base.note_id = note.id;
              base.freq = note.freq;
              base.sub_frame_index = 0;
            }

            module.paint(sample_rate, buf_span, tmp_spans);
          }

          start = note_span.end;
        }
      }

      base.iq.flush(frame_index, out.len);
    }
  };
}

const CoinVoice = struct {
  base: VoiceBase(CoinVoice, 1),
  notes: []const zang.Impulse,
  osc: zang.Oscillator,

  fn init(comptime sample_rate: u32) CoinVoice {
    const second = @floatToInt(usize, @intToFloat(f32, sample_rate));

    comptime const notes = []zang.Impulse{
      zang.Impulse{ .id = 1, .freq = 750.0, .frame = 0 },
      zang.Impulse{ .id = 2, .freq = 1000.0, .frame = second * 45 / 1000 },
      zang.Impulse{ .id = 4, .freq = null, .frame = second * 90 / 1000 },
    };

    return CoinVoice {
      .base = VoiceBase(CoinVoice, 1).init(),
      .notes = notes[0..],
      .osc = zang.Oscillator.init(.Square),
    };
  }

  fn paint(self: *CoinVoice, sample_rate: u32, out: []f32, tmp: [1][]f32) void {
    const freq_mul = self.base.freq;

    zang.zero(tmp[0]);
    self.osc.paintFromImpulses(sample_rate, tmp[0], self.notes, self.base.sub_frame_index, freq_mul, false);
    zang.multiplyWithScalar(tmp[0], 0.2);
    zang.addInto(out, tmp[0]);

    self.base.sub_frame_index += out.len;
  }
};

const CurveVoice = struct {
  base: VoiceBase(CurveVoice, 3),

  carrier_curve: []const zang.CurveNode,
  modulator_curve: []const zang.CurveNode,
  volume_curve: []const zang.CurveNode,

  carrier_mul: f32,
  modulator_mul: f32,
  modulator_rad: f32,
  curve: zang.Curve,
  carrier: zang.Oscillator,
  modulator: zang.Oscillator,

  // sample_rate arg being comptime is just me being lazy to avoid allocators
  fn init(comptime sample_rate: u32, carrier_mul: f32, modulator_mul: f32, modulator_rad: f32) CurveVoice {
    const second = @floatToInt(usize, @intToFloat(f32, sample_rate));

    const A = 1000.0;
    const B = 200.0;
    const C = 100.0;

    comptime const carrier_curve = []zang.CurveNode {
      zang.CurveNode{ .frame = 0 * second / 10, .value = A },
      zang.CurveNode{ .frame = 1 * second / 10, .value = B },
      zang.CurveNode{ .frame = 2 * second / 10, .value = C },
    };

    comptime const modulator_curve = []zang.CurveNode {
      zang.CurveNode{ .frame = 0 * second / 10, .value = A },
      zang.CurveNode{ .frame = 1 * second / 10, .value = B },
      zang.CurveNode{ .frame = 2 * second / 10, .value = C },
    };

    comptime const volume_curve = []zang.CurveNode {
      zang.CurveNode{ .frame = 0 * second / 10, .value = 0.0 },
      zang.CurveNode{ .frame = 1 * second / 250, .value = 0.35 },
      zang.CurveNode{ .frame = 2 * second / 10, .value = 0.0 },
    };

    return CurveVoice {
      .base = VoiceBase(CurveVoice, 3).init(),
      .carrier_curve = carrier_curve[0..],
      .modulator_curve = modulator_curve[0..],
      .volume_curve = volume_curve[0..],
      .carrier_mul = carrier_mul,
      .modulator_mul = modulator_mul,
      .modulator_rad = modulator_rad,
      .curve = zang.Curve.init(.SmoothStep),
      .carrier = zang.Oscillator.init(.Sine),
      .modulator = zang.Oscillator.init(.Sine),
    };
  }

  fn paint(self: *CurveVoice, sample_rate: u32, out: []f32, tmp: [3][]f32) void {
    const freq_mul = self.base.freq;

    zang.zero(tmp[0]);
    self.curve.paintFromCurve(sample_rate, tmp[0], self.modulator_curve, self.base.sub_frame_index, freq_mul * self.modulator_mul);
    zang.zero(tmp[1]);
    self.modulator.paintControlledFrequency(sample_rate, tmp[1], tmp[0]);
    zang.multiplyWithScalar(tmp[1], self.modulator_rad);
    zang.zero(tmp[0]);
    self.curve.paintFromCurve(sample_rate, tmp[0], self.carrier_curve, self.base.sub_frame_index, freq_mul * self.carrier_mul);
    zang.zero(tmp[2]);
    self.carrier.paintControlledPhaseAndFrequency(sample_rate, tmp[2], tmp[1], tmp[0]);
    zang.zero(tmp[0]);
    self.curve.paintFromCurve(sample_rate, tmp[0], self.volume_curve, self.base.sub_frame_index, null);
    zang.multiply(out, tmp[0], tmp[2]);

    self.base.sub_frame_index += out.len;
  }
};

const ExplodeVoice = struct {
  base: VoiceBase(ExplodeVoice, 3),

  cutoff_curve: []const zang.CurveNode,
  volume_curve: []const zang.CurveNode,

  curve: zang.Curve,
  noise: zang.Noise,
  filter: zang.Filter,

  // sample_rate arg being comptime is just me being lazy to avoid allocators
  fn init(comptime sample_rate: u32) ExplodeVoice {
    const second = @floatToInt(usize, @intToFloat(f32, sample_rate));

    comptime const cutoff_curve = []zang.CurveNode {
      zang.CurveNode{ .frame = 0 * second / 10, .value = comptime zang.cutoffFromFrequency(3000.0, sample_rate) },
      zang.CurveNode{ .frame = 5 * second / 10, .value = comptime zang.cutoffFromFrequency(1000.0, sample_rate) },
      zang.CurveNode{ .frame = 7 * second / 10, .value = comptime zang.cutoffFromFrequency(200.0, sample_rate) },
    };

    comptime const volume_curve = []zang.CurveNode {
      zang.CurveNode{ .frame = 0 * second / 10, .value = 0.0 },
      zang.CurveNode{ .frame = 1 * second / 250, .value = 0.75 },
      zang.CurveNode{ .frame = 7 * second / 10, .value = 0.0 },
    };

    return ExplodeVoice {
      .base = VoiceBase(ExplodeVoice, 3).init(),
      .cutoff_curve = cutoff_curve[0..],
      .volume_curve = volume_curve[0..],
      .curve = zang.Curve.init(.SmoothStep),
      .noise = zang.Noise.init(0),
      .filter = zang.Filter.init(.LowPass, 0.0, 0.0),
    };
  }

  fn paint(self: *ExplodeVoice, sample_rate: u32, out: []f32, tmp: [3][]f32) void {
    const freq = self.base.freq;

    zang.zero(tmp[0]);
    self.noise.paint(tmp[0]);
    zang.zero(tmp[1]);
    self.curve.paintFromCurve(sample_rate, tmp[1], self.cutoff_curve, self.base.sub_frame_index, freq);
    zang.zero(tmp[2]);
    self.filter.paintControlledCutoff(sample_rate, tmp[2], tmp[0], tmp[1]);
    zang.zero(tmp[1]);
    self.curve.paintFromCurve(sample_rate, tmp[1], self.volume_curve, self.base.sub_frame_index, null);
    zang.multiply(out, tmp[2], tmp[1]);

    self.base.sub_frame_index += out.len;
  }
};

pub const MainModule = struct {
  frame_index: usize,
  r: std.rand.Xoroshiro128,
  buf0: []f32,
  buf1: []f32,
  buf2: []f32,
  buf3: []f32,

  coin: CoinVoice,
  drop_web: SampleVoice,
  extra_life: SampleVoice,
  player_shot: CurveVoice,
  player_scream: SampleVoice,
  player_death: SampleVoice,
  player_crumble: SampleVoice,
  power_up: SampleVoice,
  monster_impact: SampleVoice,
  monster_shot: SampleVoice,
  monster_death: ExplodeVoice,
  wave_begin: SampleVoice,

  pub fn init(hunk_side: *HunkSide, comptime sample_rate: u32, audio_buffer_size: usize) !MainModule {
    return MainModule {
      // these allocations are never freed (but it's ok because this object is
      // create once in the main function)
      .buf0 = try hunk_side.allocator.alloc(f32, audio_buffer_size),
      .buf1 = try hunk_side.allocator.alloc(f32, audio_buffer_size),
      .buf2 = try hunk_side.allocator.alloc(f32, audio_buffer_size),
      .buf3 = try hunk_side.allocator.alloc(f32, audio_buffer_size),
      .r = std.rand.DefaultPrng.init(0),
      .frame_index = 0,
      .coin = CoinVoice.init(sample_rate),
      .drop_web = try SampleVoice.init("sfx_sounds_interaction5.wav"),
      .extra_life = try SampleVoice.init("sfx_sounds_powerup4.wav"),
      .player_shot = CurveVoice.init(sample_rate, 2.0, 0.5, 0.5),
      .player_scream = try SampleVoice.init("sfx_deathscream_human2.wav"),
      .player_death = try SampleVoice.init("sfx_exp_cluster7.wav"),
      .player_crumble = try SampleVoice.init("sfx_exp_short_soft10.wav"),
      .power_up = try SampleVoice.init("sfx_sounds_powerup10.wav"),
      .monster_impact = try SampleVoice.init("sfx_sounds_impact1.wav"),
      .monster_shot = try SampleVoice.init("sfx_wpn_laser10.wav"),
      .monster_death = ExplodeVoice.init(sample_rate),
      .wave_begin = try SampleVoice.init("sfx_sound_mechanicalnoise2.wav"),
    };
  }

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

  pub fn paint(self: *MainModule, platform_audio_state: *const PlatformAudioState) []const f32 {
    const out = self.buf0;
    const tmp0 = self.buf1;
    const tmp1 = self.buf2;
    const tmp2 = self.buf3;

    zang.zero(out);

    const mix_freq = platform_audio_state.frequency / platform_audio_state.speed;

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

    self.frame_index += out.len;

    return out;
  }
};
