const zang = @import("zang");

pub const LaserVoice = struct {
  pub const NumOutputs = 1;
  pub const NumTemps = 3;
  pub const Params = struct {
    freq_mul: f32,
    carrier_mul: f32,
    modulator_mul: f32,
    modulator_rad: f32,
  };

  pub const SoundDuration = 0.5;

  const Notes = zang.Notes(Params);

  carrier_curve: zang.Curve,
  carrier: zang.Oscillator,
  modulator_curve: zang.Curve,
  modulator: zang.Oscillator,
  volume_curve: zang.Curve,

  pub fn init() LaserVoice {
    return LaserVoice {
      .carrier_curve = zang.Curve.init(.SmoothStep, []zang.CurveNode {
        zang.CurveNode{ .value = 1000.0, .t = 0.0 },
        zang.CurveNode{ .value = 200.0, .t = 0.1 },
        zang.CurveNode{ .value = 100.0, .t = 0.2 },
      }),
      .carrier = zang.Oscillator.init(),
      .modulator_curve = zang.Curve.init(.SmoothStep, []zang.CurveNode {
        zang.CurveNode{ .value = 1000.0, .t = 0.0 },
        zang.CurveNode{ .value = 200.0, .t = 0.1 },
        zang.CurveNode{ .value = 100.0, .t = 0.2 },
      }),
      .modulator = zang.Oscillator.init(),
      .volume_curve = zang.Curve.init(.SmoothStep, []zang.CurveNode {
        zang.CurveNode{ .value = 0.0, .t = 0.0 },
        zang.CurveNode{ .value = 0.35, .t = 0.004 },
        zang.CurveNode{ .value = 0.0, .t = 0.2 },
      }),
    };
  }

  pub fn reset(self: *LaserVoice) void {
    self.carrier_curve.reset();
    self.modulator_curve.reset();
    self.volume_curve.reset();
  }

  pub fn paint(self: *LaserVoice, sample_rate: f32, outputs: [NumOutputs][]f32, temps: [NumTemps][]f32, params: Params) void {
    const out = outputs[0];

    zang.zero(temps[0]);
    self.modulator_curve.paint(sample_rate, [1][]f32{temps[0]}, [0][]f32{}, zang.Curve.Params {
      .freq_mul = params.freq_mul * params.modulator_mul,
    });
    zang.zero(temps[1]);
    self.modulator.paint(sample_rate, [1][]f32{temps[1]}, [0][]f32{}, zang.Oscillator.Params {
      .waveform = .Sine,
      .freq = zang.buffer(temps[0]),
      .phase = zang.constant(0.0),
      .colour = 0.5,
    });
    zang.multiplyWithScalar(temps[1], params.modulator_rad);
    zang.zero(temps[0]);
    self.carrier_curve.paint(sample_rate, [1][]f32{temps[0]}, [0][]f32{}, zang.Curve.Params {
      .freq_mul = params.freq_mul * params.carrier_mul,
    });
    zang.zero(temps[2]);
    self.carrier.paint(sample_rate, [1][]f32{temps[2]}, [0][]f32{}, zang.Oscillator.Params {
      .waveform = .Sine,
      .freq = zang.buffer(temps[0]),
      .phase = zang.buffer(temps[1]),
      .colour = 0.5,
    });
    zang.zero(temps[0]);
    self.volume_curve.paint(sample_rate, [1][]f32{temps[0]}, [0][]f32{}, zang.Curve.Params {
      .freq_mul = 1.0,
    });
    zang.multiply(out, temps[0], temps[2]);
  }
};
