const zang = @import("zang");

pub const ExplosionVoice = struct {
    pub const num_outputs = 1;
    pub const num_temps = 3;
    pub const Params = struct { sample_rate: f32, unused: bool };
    pub const NoteParams = struct { unused: bool };

    pub const sound_duration = 0.7;

    cutoff_curve: zang.Curve,
    volume_curve: zang.Curve,
    noise: zang.Noise,
    filter: zang.Filter,

    pub fn init() ExplosionVoice {
        return .{
            .cutoff_curve = zang.Curve.init(),
            .volume_curve = zang.Curve.init(),
            .noise = zang.Noise.init(0),
            .filter = zang.Filter.init(),
        };
    }

    pub fn paint(
        self: *ExplosionVoice,
        span: zang.Span,
        outputs: [num_outputs][]f32,
        temps: [num_temps][]f32,
        note_id_changed: bool,
        params: Params,
    ) void {
        const out = outputs[0];

        zang.zero(span, temps[0]);
        self.noise.paint(span, .{temps[0]}, .{}, .{});
        zang.zero(span, temps[1]);
        self.cutoff_curve.paint(span, .{temps[1]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .function = .smoothstep,
            .curve = &[_]zang.CurveNode {
                .{ .t = 0.0, .value = 3000.0 },
                .{ .t = 0.5, .value = 1000.0 },
                .{ .t = 0.7, .value = 200.0 },
            },
            .freq_mul = 1.0,
        });
        // FIXME - apply this to the curve nodes before interpolation, to save
        // time. but this probably requires a change to the zang api
        var i: usize = 0; while (i < temps[1].len) : (i += 1) {
            temps[1][i] =
                zang.cutoffFromFrequency(temps[1][i], params.sample_rate);
        }
        zang.zero(span, temps[2]);
        self.filter.paint(span, .{temps[2]}, .{}, .{
            .input = temps[0],
            .filter_type = .low_pass,
            .cutoff = zang.buffer(temps[1]),
            .resonance = 0.0,
        });
        zang.zero(span, temps[1]);
        self.volume_curve.paint(span, .{temps[1]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .function = .smoothstep,
            .curve = &[_]zang.CurveNode {
                .{ .t = 0.0, .value = 0.0 },
                .{ .t = 0.004, .value = 0.75 },
                .{ .t = 0.7, .value = 0.0 },
            },
            .freq_mul = 1.0,
        });
        zang.multiply(span, out, temps[2], temps[1]);
    }
};
