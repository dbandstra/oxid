const zang = @import("zang");
const VoiceBase = @import("base.zig").VoiceBase;

pub const ExplosionVoice = struct {
  base: VoiceBase(ExplosionVoice, 3),

  cutoff_curve: []const zang.CurveNode,
  volume_curve: []const zang.CurveNode,

  curve: zang.Curve,
  noise: zang.Noise,
  filter: zang.Filter,

  // sample_rate arg being comptime is just me being lazy to avoid allocators
  pub fn init(comptime sample_rate: u32) ExplosionVoice {
    const second = @floatToInt(usize, @intToFloat(f32, sample_rate));

    comptime const cutoff_curve = []zang.CurveNode {
      zang.CurveNode{ .frame = 0 * second / 10, .value = comptime zang.cutoffFromFrequency(3000.0, sample_rate) },
      zang.CurveNode{ .frame = 5 * second / 10, .value = comptime zang.cutoffFromFrequency(1000.0, sample_rate) },
      zang.CurveNode{ .frame = 7 * second / 10, .value = comptime zang.cutoffFromFrequency(200.0, sample_rate) },
    };

    comptime const volume_curve = []zang.CurveNode {
      zang.CurveNode{ .frame = 0 * second / 10, .value = 0.0 },
      zang.CurveNode{ .frame = 1 * second / 250, .value = 0.75 },
      zang.CurveNode{ .frame = 7 * second / 10, .value = 0.0 },
    };

    return ExplosionVoice {
      .base = VoiceBase(ExplosionVoice, 3).init(),
      .cutoff_curve = cutoff_curve[0..],
      .volume_curve = volume_curve[0..],
      .curve = zang.Curve.init(.SmoothStep),
      .noise = zang.Noise.init(0),
      .filter = zang.Filter.init(.LowPass, 0.0, 0.0),
    };
  }

  pub fn paint(self: *ExplosionVoice, sample_rate: u32, out: []f32, tmp: [3][]f32) void {
    const freq = self.base.freq;

    zang.zero(tmp[0]);
    self.noise.paint(tmp[0]);
    zang.zero(tmp[1]);
    self.curve.paintFromCurve(sample_rate, tmp[1], self.cutoff_curve, self.base.sub_frame_index, freq);
    zang.zero(tmp[2]);
    self.filter.paintControlledCutoff(sample_rate, tmp[2], tmp[0], tmp[1]);
    zang.zero(tmp[1]);
    self.curve.paintFromCurve(sample_rate, tmp[1], self.volume_curve, self.base.sub_frame_index, null);
    zang.multiply(out, tmp[2], tmp[1]);

    self.base.sub_frame_index += out.len;
  }
};
