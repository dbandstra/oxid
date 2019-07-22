const zang = @import("zang");

pub const LaserVoice = struct {
    pub const NumOutputs = 1;
    pub const NumTemps = 3;
    pub const Params = struct {
        sample_rate: f32,
        freq_mul: f32,
        carrier_mul: f32,
        modulator_mul: f32,
        modulator_rad: f32,
    };
    pub const NoteParams = struct {
        freq_mul: f32,
        carrier_mul: f32,
        modulator_mul: f32,
        modulator_rad: f32,
    };

    pub const sound_duration = 0.5;

    carrier_curve: zang.Curve,
    carrier: zang.Oscillator,
    modulator_curve: zang.Curve,
    modulator: zang.Oscillator,
    volume_curve: zang.Curve,

    pub fn init() LaserVoice {
        return LaserVoice {
            .carrier_curve = zang.Curve.init(),
            .carrier = zang.Oscillator.init(),
            .modulator_curve = zang.Curve.init(),
            .modulator = zang.Oscillator.init(),
            .volume_curve = zang.Curve.init(),
        };
    }

    pub fn paint(self: *LaserVoice, span: zang.Span, outputs: [NumOutputs][]f32, temps: [NumTemps][]f32, note_id_changed: bool, params: Params) void {
        const out = outputs[0];

        zang.zero(span, temps[0]);
        self.modulator_curve.paint(span, [1][]f32{temps[0]}, [0][]f32{}, note_id_changed, zang.Curve.Params {
            .sample_rate = params.sample_rate,
            .function = .SmoothStep,
            .curve = [_]zang.CurveNode {
                zang.CurveNode { .value = 1000.0, .t = 0.0 },
                zang.CurveNode { .value = 200.0, .t = 0.1 },
                zang.CurveNode { .value = 100.0, .t = 0.2 },
            },
            .freq_mul = params.freq_mul * params.modulator_mul,
        });
        zang.zero(span, temps[1]);
        self.modulator.paint(span, [1][]f32{temps[1]}, [0][]f32{}, zang.Oscillator.Params {
            .sample_rate = params.sample_rate,
            .waveform = .Sine,
            .freq = zang.buffer(temps[0]),
            .phase = zang.constant(0.0),
            .colour = 0.5,
        });
        zang.multiplyWithScalar(span, temps[1], params.modulator_rad);
        zang.zero(span, temps[0]);
        self.carrier_curve.paint(span, [1][]f32{temps[0]}, [0][]f32{}, note_id_changed, zang.Curve.Params {
            .sample_rate = params.sample_rate,
            .function = .SmoothStep,
            .curve = [_]zang.CurveNode {
                zang.CurveNode { .value = 1000.0, .t = 0.0 },
                zang.CurveNode { .value = 200.0, .t = 0.1 },
                zang.CurveNode { .value = 100.0, .t = 0.2 },
            },
            .freq_mul = params.freq_mul * params.carrier_mul,
        });
        zang.zero(span, temps[2]);
        self.carrier.paint(span, [1][]f32{temps[2]}, [0][]f32{}, zang.Oscillator.Params {
            .sample_rate = params.sample_rate,
            .waveform = .Sine,
            .freq = zang.buffer(temps[0]),
            .phase = zang.buffer(temps[1]),
            .colour = 0.5,
        });
        zang.zero(span, temps[0]);
        self.volume_curve.paint(span, [1][]f32{temps[0]}, [0][]f32{}, note_id_changed, zang.Curve.Params {
            .sample_rate = params.sample_rate,
            .function = .SmoothStep,
            .curve = [_]zang.CurveNode {
                zang.CurveNode { .value = 0.0, .t = 0.0 },
                zang.CurveNode { .value = 0.35, .t = 0.004 },
                zang.CurveNode { .value = 0.0, .t = 0.2 },
            },
            .freq_mul = 1.0,
        });
        zang.multiply(span, out, temps[0], temps[2]);
    }
};
