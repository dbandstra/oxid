const zang = @import("zang");
const VoiceBase = @import("base.zig").VoiceBase;

pub const LaserVoice = struct {
  base: VoiceBase(LaserVoice, 3),

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
  pub fn init(comptime sample_rate: u32, carrier_mul: f32, modulator_mul: f32, modulator_rad: f32) LaserVoice {
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

    return LaserVoice {
      .base = VoiceBase(LaserVoice, 3).init(),
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

  pub fn paint(self: *LaserVoice, sample_rate: u32, out: []f32, tmp: [3][]f32) void {
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
