const zang = @import("zang");

pub const LaserVoice = struct {
  pub const NumTempBufs = 3;

  iq: zang.ImpulseQueue,
  trigger: zang.Trigger(LaserVoice),

  carrier_mul: f32,
  carrier_curve: zang.Curve,
  carrier: zang.Oscillator,
  modulator_mul: f32,
  modulator_rad: f32,
  modulator_curve: zang.Curve,
  modulator: zang.Oscillator,
  volume_curve: zang.Curve,

  pub fn init(carrier_mul: f32, modulator_mul: f32, modulator_rad: f32) LaserVoice {
    return LaserVoice {
      .iq = zang.ImpulseQueue.init(),
      .trigger = zang.Trigger(LaserVoice).init(),
      .carrier_mul = carrier_mul,
      .carrier_curve = zang.Curve.init(.SmoothStep, []zang.CurveNode {
        zang.CurveNode{ .value = 1000.0, .t = 0.0 },
        zang.CurveNode{ .value = 200.0, .t = 0.1 },
        zang.CurveNode{ .value = 100.0, .t = 0.2 },
      }),
      .carrier = zang.Oscillator.init(.Sine),
      .modulator_mul = modulator_mul,
      .modulator_rad = modulator_rad,
      .modulator_curve = zang.Curve.init(.SmoothStep, []zang.CurveNode {
        zang.CurveNode{ .value = 1000.0, .t = 0.0 },
        zang.CurveNode{ .value = 200.0, .t = 0.1 },
        zang.CurveNode{ .value = 100.0, .t = 0.2 },
      }),
      .modulator = zang.Oscillator.init(.Sine),
      .volume_curve = zang.Curve.init(.SmoothStep, []zang.CurveNode {
        zang.CurveNode{ .value = 0.0, .t = 0.0 },
        zang.CurveNode{ .value = 0.35, .t = 0.004 },
        zang.CurveNode{ .value = 0.0, .t = 0.2 },
      }),
    };
  }

  pub fn paint(self: *LaserVoice, sample_rate: f32, out: []f32, note_on: bool, freq: f32, tmp: [3][]f32) void {
    const freq_mul = freq;

    zang.zero(tmp[0]);
    self.modulator_curve.paint(sample_rate, tmp[0], freq_mul * self.modulator_mul);
    zang.zero(tmp[1]);
    self.modulator.paintControlledFrequency(sample_rate, tmp[1], tmp[0]);
    zang.multiplyWithScalar(tmp[1], self.modulator_rad);
    zang.zero(tmp[0]);
    self.carrier_curve.paint(sample_rate, tmp[0], freq_mul * self.carrier_mul);
    zang.zero(tmp[2]);
    self.carrier.paintControlledPhaseAndFrequency(sample_rate, tmp[2], tmp[1], tmp[0]);
    zang.zero(tmp[0]);
    self.volume_curve.paint(sample_rate, tmp[0], null);
    zang.multiply(out, tmp[0], tmp[2]);
  }

  pub fn reset(self: *LaserVoice) void {
    self.carrier_curve.reset();
    self.modulator_curve.reset();
    self.volume_curve.reset();
  }
};
