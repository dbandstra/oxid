const zang = @import("zang");

pub const LaserVoice = struct {
    pub const num_outputs = 1;
    pub const num_temps = 3;
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
    carrier: zang.SineOsc,
    modulator_curve: zang.Curve,
    modulator: zang.SineOsc,
    volume_curve: zang.Curve,

    pub fn init() LaserVoice {
        return .{
            .carrier_curve = zang.Curve.init(),
            .carrier = zang.SineOsc.init(),
            .modulator_curve = zang.Curve.init(),
            .modulator = zang.SineOsc.init(),
            .volume_curve = zang.Curve.init(),
        };
    }

    pub fn paint(self: *LaserVoice, span: zang.Span, outputs: [num_outputs][]f32, temps: [num_temps][]f32, note_id_changed: bool, params: Params) void {
        const out = outputs[0];

        zang.zero(span, temps[0]);
        self.modulator_curve.paint(span, .{temps[0]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .function = .SmoothStep,
            .curve = [_]zang.CurveNode {
  // https://github.com/ziglang/zig/issues/3679
  zang.CurveNode { .value = 1000.0, .t = 0.0 },
                .{ .value = 200.0, .t = 0.1 },
                .{ .value = 100.0, .t = 0.2 },
            },
            .freq_mul = params.freq_mul * params.modulator_mul,
        });
        zang.zero(span, temps[1]);
        self.modulator.paint(span, .{temps[1]}, .{}, .{
            .sample_rate = params.sample_rate,
            .freq = zang.buffer(temps[0]),
            .phase = zang.constant(0.0),
        });
        zang.multiplyWithScalar(span, temps[1], params.modulator_rad);
        zang.zero(span, temps[0]);
        self.carrier_curve.paint(span, .{temps[0]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .function = .SmoothStep,
            .curve = [_]zang.CurveNode {
  // https://github.com/ziglang/zig/issues/3679
  zang.CurveNode { .value = 1000.0, .t = 0.0 },
                .{ .value = 200.0, .t = 0.1 },
                .{ .value = 100.0, .t = 0.2 },
            },
            .freq_mul = params.freq_mul * params.carrier_mul,
        });
        zang.zero(span, temps[2]);
        self.carrier.paint(span, .{temps[2]}, .{}, .{
            .sample_rate = params.sample_rate,
            .freq = zang.buffer(temps[0]),
            .phase = zang.buffer(temps[1]),
        });
        zang.zero(span, temps[0]);
        self.volume_curve.paint(span, .{temps[0]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .function = .SmoothStep,
            .curve = [_]zang.CurveNode {
  // https://github.com/ziglang/zig/issues/3679
  zang.CurveNode { .value = 0.0, .t = 0.0 },
                .{ .value = 0.35, .t = 0.004 },
                .{ .value = 0.0, .t = 0.2 },
            },
            .freq_mul = 1.0,
        });
        zang.multiply(span, out, temps[0], temps[2]);
    }
};
