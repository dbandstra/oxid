const zang = @import("zang");
const VoiceBase = @import("base.zig").VoiceBase;

pub const CoinVoice = struct {
  base: VoiceBase(CoinVoice, 1),
  notes: []const zang.Impulse,
  osc: zang.Oscillator,

  pub fn init(comptime sample_rate: u32) CoinVoice {
    const second = @floatToInt(usize, @intToFloat(f32, sample_rate));

    comptime const notes = []zang.Impulse{
      zang.Impulse{ .id = 1, .freq = 750.0, .frame = 0 },
      zang.Impulse{ .id = 2, .freq = 1000.0, .frame = second * 45 / 1000 },
      zang.Impulse{ .id = 4, .freq = null, .frame = second * 90 / 1000 },
    };

    return CoinVoice {
      .base = VoiceBase(CoinVoice, 1).init(),
      .notes = notes[0..],
      .osc = zang.Oscillator.init(.Square),
    };
  }

  pub fn paint(self: *CoinVoice, sample_rate: u32, out: []f32, tmp: [1][]f32) void {
    const freq_mul = self.base.freq;

    zang.zero(tmp[0]);
    self.osc.paintFromImpulses(sample_rate, tmp[0], self.notes, self.base.sub_frame_index, freq_mul, false);
    zang.multiplyWithScalar(tmp[0], 0.2);
    zang.addInto(out, tmp[0]);

    self.base.sub_frame_index += out.len;
  }
};
