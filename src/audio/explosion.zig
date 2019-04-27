const zang = @import("zang");

pub const ExplosionVoice = struct {
  pub const NumOutputs = 1;
  pub const NumInputs = 0;
  pub const NumTemps = 3;
  pub const Params = struct {};

  pub const SoundDuration = 0.7;

  const Notes = zang.Notes(Params);

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
      .filter = zang.Filter.init(.LowPass),
    };
  }

  pub fn reset(self: *ExplosionVoice) void {
    self.cutoff_curve.reset();
    self.volume_curve.reset();
  }

  pub fn paintSpan(self: *ExplosionVoice, sample_rate: f32, outputs: [NumOutputs][]f32, inputs: [NumInputs][]f32, temps: [NumTemps][]f32, params: Params) void {
    const out = outputs[0];

    zang.zero(temps[0]);
    self.noise.paintSpan(sample_rate, [1][]f32{temps[0]}, [0][]f32{}, [0][]f32{}, zang.Noise.Params {});
    zang.zero(temps[1]);
    self.cutoff_curve.paintSpan(sample_rate, [1][]f32{temps[1]}, [0][]f32{}, [0][]f32{}, zang.Curve.Params {
      .freq_mul = 1.0,
    });
    // FIXME - apply this to the curve nodes before interpolation, to save
    // time. but this probably requires a change to the zang api
    var i: usize = 0; while (i < temps[1].len) : (i += 1) {
      temps[1][i] = zang.cutoffFromFrequency(temps[1][i], sample_rate);
    }
    zang.zero(temps[2]);
    self.filter.paintControlledCutoff(sample_rate, temps[2], temps[0], temps[1], 0.0);
    zang.zero(temps[1]);
    self.volume_curve.paintSpan(sample_rate, [1][]f32{temps[1]}, [0][]f32{}, [0][]f32{}, zang.Curve.Params {
      .freq_mul = 1.0,
    });
    zang.multiply(out, temps[2], temps[1]);
  }
};
