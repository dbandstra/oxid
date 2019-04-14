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

const CoinVoice = struct {
  notes: []const zang.Impulse,

  iq: zang.ImpulseQueue,

  osc: zang.Oscillator,

  sub_frame_index: usize,
  note_id: usize,
  freq: f32,

  fn init(comptime sample_rate: u32) CoinVoice {
    const second = @floatToInt(usize, @intToFloat(f32, sample_rate));

    comptime const notes = []zang.Impulse{
      zang.Impulse{ .id = 1, .freq = 750.0, .frame = 0 },
      zang.Impulse{ .id = 2, .freq = 1000.0, .frame = second * 45 / 1000 },
      zang.Impulse{ .id = 4, .freq = null, .frame = second * 90 / 1000 },
    };

    return CoinVoice {
      .notes = notes[0..],
      .iq = zang.ImpulseQueue.init(),
      .osc = zang.Oscillator.init(.Square),
      .sub_frame_index = 0,
      .note_id = 0,
      .freq = 0.0,
    };
  }

  fn paint(self: *CoinVoice, sample_rate: u32, out: []f32, tmp0: []f32) void {
    const freq_mul = self.freq;

    zang.zero(tmp0);
    self.osc.paintFromImpulses(sample_rate, tmp0, self.notes, self.sub_frame_index, freq_mul, false);
    zang.multiplyWithScalar(tmp0, 0.2);
    zang.addInto(out, tmp0);

    self.sub_frame_index += out.len;
  }

  fn update(
    self: *CoinVoice,
    sample_rate: u32,
    out: []f32,
    tmp0: []f32,
    frame_index: usize,
  ) void {
    std.debug.assert(out.len == tmp0.len);

    if (!self.iq.isEmpty()) {
      const track = self.iq.getImpulses();

      var start: usize = 0;

      while (start < out.len) {
        const note_span = zang.getNextNoteSpan(track, frame_index, start, out.len);

        std.debug.assert(note_span.start == start);
        std.debug.assert(note_span.end > start);
        std.debug.assert(note_span.end <= out.len);

        const buf_span = out[note_span.start .. note_span.end];
        const tmp0_span = tmp0[note_span.start .. note_span.end];

        if (note_span.note) |note| {
          if (note.id != self.note_id) {
            std.debug.assert(note.id > self.note_id);

            self.note_id = note.id;
            self.freq = note.freq;
            self.sub_frame_index = 0;
          }

          self.paint(sample_rate, buf_span, tmp0_span);
        }

        start = note_span.end;
      }
    }

    self.iq.flush(frame_index, out.len);
  }
};

const CurveVoice = struct {
  carrier_curve: []const zang.CurveNode,
  modulator_curve: []const zang.CurveNode,
  volume_curve: []const zang.CurveNode,

  iq: zang.ImpulseQueue,

  carrier_mul: f32,
  modulator_mul: f32,
  modulator_rad: f32,
  curve: zang.Curve,
  carrier: zang.Oscillator,
  modulator: zang.Oscillator,
  sub_frame_index: usize,
  note_id: usize,
  freq: f32,

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

    return CurveVoice{
      .carrier_curve = carrier_curve[0..],
      .modulator_curve = modulator_curve[0..],
      .volume_curve = volume_curve[0..],
      .iq = zang.ImpulseQueue.init(),
      .carrier_mul = carrier_mul,
      .modulator_mul = modulator_mul,
      .modulator_rad = modulator_rad,
      .curve = zang.Curve.init(.SmoothStep),
      .carrier = zang.Oscillator.init(.Sine),
      .modulator = zang.Oscillator.init(.Sine),
      .sub_frame_index = 0,
      .note_id = 0,
      .freq = 0.0,
    };
  }

  fn paint(self: *CurveVoice, sample_rate: u32, out: []f32, tmp0: []f32, tmp1: []f32, tmp2: []f32) void {
    const freq_mul = self.freq;

    zang.zero(tmp0);
    self.curve.paintFromCurve(sample_rate, tmp0, self.modulator_curve, self.sub_frame_index, freq_mul * self.modulator_mul);
    zang.zero(tmp1);
    self.modulator.paintControlledFrequency(sample_rate, tmp1, tmp0);
    zang.multiplyWithScalar(tmp1, self.modulator_rad);
    zang.zero(tmp0);
    self.curve.paintFromCurve(sample_rate, tmp0, self.carrier_curve, self.sub_frame_index, freq_mul * self.carrier_mul);
    zang.zero(tmp2);
    self.carrier.paintControlledPhaseAndFrequency(sample_rate, tmp2, tmp1, tmp0);
    zang.zero(tmp0);
    self.curve.paintFromCurve(sample_rate, tmp0, self.volume_curve, self.sub_frame_index, null);
    zang.multiply(out, tmp0, tmp2);

    self.sub_frame_index += out.len;
  }

  fn update(
    self: *CurveVoice,
    sample_rate: u32,
    out: []f32,
    tmp0: []f32,
    tmp1: []f32,
    tmp2: []f32,
    frame_index: usize,
  ) void {
    std.debug.assert(out.len == tmp0.len);
    std.debug.assert(out.len == tmp1.len);
    std.debug.assert(out.len == tmp2.len);

    if (!self.iq.isEmpty()) {
      const track = self.iq.getImpulses();

      var start: usize = 0;

      while (start < out.len) {
        const note_span = zang.getNextNoteSpan(track, frame_index, start, out.len);

        std.debug.assert(note_span.start == start);
        std.debug.assert(note_span.end > start);
        std.debug.assert(note_span.end <= out.len);

        const buf_span = out[note_span.start .. note_span.end];
        const tmp0_span = tmp0[note_span.start .. note_span.end];
        const tmp1_span = tmp1[note_span.start .. note_span.end];
        const tmp2_span = tmp2[note_span.start .. note_span.end];

        if (note_span.note) |note| {
          if (note.id != self.note_id) {
            std.debug.assert(note.id > self.note_id);

            self.note_id = note.id;
            self.freq = note.freq;
            self.sub_frame_index = 0;
          }

          self.paint(sample_rate, buf_span, tmp0_span, tmp1_span, tmp2_span);
        } else {
          // gap between notes. but keep playing (sampler currently ignores note
          // end events).

          // don't paint at all if note_freq is null. that means we haven't hit
          // the first note yet
          if (self.note_id > 0) {
            self.paint(sample_rate, buf_span, tmp0_span, tmp1_span, tmp2_span);
          }
        }

        start = note_span.end;
      }
    }

    self.iq.flush(frame_index, out.len);
  }
};

pub const MainModule = struct {
  frame_index: usize,
  r: std.rand.Xoroshiro128,
  buf0: []f32,
  buf1: []f32,
  buf2: []f32,
  buf3: []f32,

  laser: CurveVoice,
  coin: CoinVoice,
  drop_web: SampleVoice,
  extra_life: SampleVoice,
  player_scream: SampleVoice,
  player_death: SampleVoice,
  player_crumble: SampleVoice,
  power_up: SampleVoice,
  monster_impact: SampleVoice,
  monster_shot: SampleVoice,
  monster_death: SampleVoice,
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
      .laser = CurveVoice.init(sample_rate, 2.0, 0.5, 0.5),
      .coin = CoinVoice.init(sample_rate),
      .drop_web = try SampleVoice.init("sfx_sounds_interaction5.wav"),
      .extra_life = try SampleVoice.init("sfx_sounds_powerup4.wav"),
      .player_scream = try SampleVoice.init("sfx_deathscream_human2.wav"),
      .player_death = try SampleVoice.init("sfx_exp_cluster7.wav"),
      .player_crumble = try SampleVoice.init("sfx_exp_short_soft10.wav"),
      .power_up = try SampleVoice.init("sfx_sounds_powerup10.wav"),
      .monster_impact = try SampleVoice.init("sfx_sounds_impact1.wav"),
      .monster_shot = try SampleVoice.init("sfx_wpn_laser10.wav"),
      .monster_death = try SampleVoice.init("sfx_exp_short_soft5.wav"),
      .wave_begin = try SampleVoice.init("sfx_sound_mechanicalnoise2.wav"),
    };
  }

  pub fn playSample(self: *MainModule, sample: Sample) void {
    const maybe_iq = switch (sample) {
      .Accelerate => null, // TODO
      .Coin => &self.coin.iq,
      .DropWeb => &self.drop_web.iq,
      .ExtraLife => &self.extra_life.iq,
      .PlayerShot => &self.laser.iq,
      .PlayerScream => &self.player_scream.iq,
      .PlayerDeath => &self.player_death.iq,
      .PlayerCrumble => &self.player_crumble.iq,
      .PowerUp => &self.power_up.iq,
      .MonsterImpact => &self.monster_impact.iq,
      .MonsterShot => &self.monster_shot.iq,
      .MonsterDeath => &self.monster_death.iq,
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

    self.laser.update(mix_freq, out, tmp0, tmp1, tmp2, self.frame_index);
    self.coin.update(mix_freq, out, tmp0, self.frame_index);
    self.drop_web.update(mix_freq, out, self.frame_index);
    self.extra_life.update(mix_freq, out, self.frame_index);
    self.player_scream.update(mix_freq, out, self.frame_index);
    self.player_death.update(mix_freq, out, self.frame_index);
    self.player_crumble.update(mix_freq, out, self.frame_index);
    self.power_up.update(mix_freq, out, self.frame_index);
    self.monster_impact.update(mix_freq, out, self.frame_index);
    self.monster_shot.update(mix_freq, out, self.frame_index);
    self.monster_death.update(mix_freq, out, self.frame_index);
    self.wave_begin.update(mix_freq, out, self.frame_index);

    self.frame_index += out.len;

    return out;
  }
};
