const zang = @import("zang");

pub const ExplosionVoice = struct {
  pub const NumTempBufs = 3;

  cutoff_tracker: zang.CurveTracker,
  volume_tracker: zang.CurveTracker,

  curve: zang.Curve,
  noise: zang.Noise,
  filter: zang.Filter,

  pub fn init() ExplosionVoice {
    return ExplosionVoice {
      .cutoff_tracker = zang.CurveTracker.init([]zang.CurveTrackerNode {
        zang.CurveTrackerNode{ .t = 0.0, .value = 3000.0 },
        zang.CurveTrackerNode{ .t = 0.5, .value = 1000.0 },
        zang.CurveTrackerNode{ .t = 0.7, .value = 200.0 },
      }),
      .volume_tracker = zang.CurveTracker.init([]zang.CurveTrackerNode {
        zang.CurveTrackerNode{ .t = 0.0, .value = 0.0 },
        zang.CurveTrackerNode{ .t = 0.004, .value = 0.75 },
        zang.CurveTrackerNode{ .t = 0.7, .value = 0.0 },
      }),
      .curve = zang.Curve.init(.SmoothStep),
      .noise = zang.Noise.init(0),
      .filter = zang.Filter.init(.LowPass, 0.0, 0.0),
    };
  }

  pub fn paint(self: *ExplosionVoice, sample_rate: f32, out: []f32, note_on: bool, freq: f32, tmp: [3][]f32) void {
    const cutoff_curve = self.cutoff_tracker.getCurveNodes(sample_rate, out.len);
    const volume_curve = self.volume_tracker.getCurveNodes(sample_rate, out.len);

    for (cutoff_curve) |*node| {
      node.value = zang.cutoffFromFrequency(node.value, sample_rate);
    }

    zang.zero(tmp[0]);
    self.noise.paint(tmp[0]);
    zang.zero(tmp[1]);
    self.curve.paintFromCurve(tmp[1], cutoff_curve, freq);
    zang.zero(tmp[2]);
    self.filter.paintControlledCutoff(sample_rate, tmp[2], tmp[0], tmp[1]);
    zang.zero(tmp[1]);
    self.curve.paintFromCurve(tmp[1], volume_curve, null);
    zang.multiply(out, tmp[2], tmp[1]);
  }

  pub fn reset(self: *ExplosionVoice) void {
    self.cutoff_tracker.reset();
    self.volume_tracker.reset();
  }
};
