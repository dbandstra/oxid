const zang = @import("zang");

pub const ExplosionVoice = struct {
  pub const NumTempBufs = 3;

  cutoff_curve: zang.Curve,
  volume_curve: zang.Curve,
  noise: zang.Noise,
  filter: zang.Filter,

  pub fn init() ExplosionVoice {
    return ExplosionVoice {
      .cutoff_curve = zang.Curve.init(.SmoothStep, []zang.CurveNode {
        zang.CurveNode{ .t = 0.0, .value = 3000.0 },
        zang.CurveNode{ .t = 0.5, .value = 1000.0 },
        zang.CurveNode{ .t = 0.7, .value = 200.0 },
      }),
      .volume_curve = zang.Curve.init(.SmoothStep, []zang.CurveNode {
        zang.CurveNode{ .t = 0.0, .value = 0.0 },
        zang.CurveNode{ .t = 0.004, .value = 0.75 },
        zang.CurveNode{ .t = 0.7, .value = 0.0 },
      }),
      .noise = zang.Noise.init(0),
      .filter = zang.Filter.init(.LowPass, 0.0, 0.0),
    };
  }

  pub fn paint(self: *ExplosionVoice, sample_rate: f32, out: []f32, note_on: bool, freq: f32, tmp: [3][]f32) void {
    zang.zero(tmp[0]);
    self.noise.paint(tmp[0]);
    zang.zero(tmp[1]);
    self.cutoff_curve.paint(sample_rate, tmp[1], freq);
    // FIXME - apply this to the curve nodes before interpolation, to save
    // time. but this probably requires a change to the zang api
    var i: usize = 0; while (i < tmp[1].len) : (i += 1) {
      tmp[1][i] = zang.cutoffFromFrequency(tmp[1][i], sample_rate);
    }
    zang.zero(tmp[2]);
    self.filter.paintControlledCutoff(sample_rate, tmp[2], tmp[0], tmp[1]);
    zang.zero(tmp[1]);
    self.volume_curve.paint(sample_rate, tmp[1], null);
    zang.multiply(out, tmp[2], tmp[1]);
  }

  pub fn reset(self: *ExplosionVoice) void {
    self.cutoff_curve.reset();
    self.volume_curve.reset();
  }
};
