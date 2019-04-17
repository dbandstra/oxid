const zang = @import("zang");

pub const LaserVoice = struct {
  pub const NumTempBufs = 3;

  carrier_tracker: zang.CurveTracker,
  modulator_tracker: zang.CurveTracker,
  volume_tracker: zang.CurveTracker,

  carrier_mul: f32,
  modulator_mul: f32,
  modulator_rad: f32,
  curve: zang.Curve,
  carrier: zang.Oscillator,
  modulator: zang.Oscillator,

  pub fn init(carrier_mul: f32, modulator_mul: f32, modulator_rad: f32) LaserVoice {
    const A = 1000.0;
    const B = 200.0;
    const C = 100.0;

    return LaserVoice {
      .carrier_tracker = zang.CurveTracker.init([]zang.CurveTrackerNode {
        zang.CurveTrackerNode{ .value = A, .t = 0.0 },
        zang.CurveTrackerNode{ .value = B, .t = 0.1 },
        zang.CurveTrackerNode{ .value = C, .t = 0.2 },
      }),
      .modulator_tracker = zang.CurveTracker.init([]zang.CurveTrackerNode {
        zang.CurveTrackerNode{ .value = A, .t = 0.0 },
        zang.CurveTrackerNode{ .value = B, .t = 0.1 },
        zang.CurveTrackerNode{ .value = C, .t = 0.2 },
      }),
      .volume_tracker = zang.CurveTracker.init([]zang.CurveTrackerNode {
        zang.CurveTrackerNode{ .value = 0.0, .t = 0.0 },
        zang.CurveTrackerNode{ .value = 0.35, .t = 0.004 },
        zang.CurveTrackerNode{ .value = 0.0, .t = 0.2 },
      }),
      .carrier_mul = carrier_mul,
      .modulator_mul = modulator_mul,
      .modulator_rad = modulator_rad,
      .curve = zang.Curve.init(.SmoothStep),
      .carrier = zang.Oscillator.init(.Sine),
      .modulator = zang.Oscillator.init(.Sine),
    };
  }

  pub fn paint(self: *LaserVoice, sample_rate: f32, out: []f32, note_on: bool, freq: f32, tmp: [3][]f32) void {
    const carrier_curve = self.carrier_tracker.getCurveNodes(sample_rate, out.len);
    const modulator_curve = self.modulator_tracker.getCurveNodes(sample_rate, out.len);
    const volume_curve = self.volume_tracker.getCurveNodes(sample_rate, out.len);
    const freq_mul = freq;

    zang.zero(tmp[0]);
    self.curve.paintFromCurve(tmp[0], modulator_curve, freq_mul * self.modulator_mul);
    zang.zero(tmp[1]);
    self.modulator.paintControlledFrequency(sample_rate, tmp[1], tmp[0]);
    zang.multiplyWithScalar(tmp[1], self.modulator_rad);
    zang.zero(tmp[0]);
    self.curve.paintFromCurve(tmp[0], carrier_curve, freq_mul * self.carrier_mul);
    zang.zero(tmp[2]);
    self.carrier.paintControlledPhaseAndFrequency(sample_rate, tmp[2], tmp[1], tmp[0]);
    zang.zero(tmp[0]);
    self.curve.paintFromCurve(tmp[0], volume_curve, null);
    zang.multiply(out, tmp[0], tmp[2]);
  }

  pub fn reset(self: *LaserVoice) void {
    self.carrier_tracker.reset();
    self.modulator_tracker.reset();
    self.volume_tracker.reset();
  }
};
