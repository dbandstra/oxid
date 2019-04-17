const zang = @import("zang");

pub const CoinVoice = struct {
  pub const NumTempBufs = 2;

  osc: zang.Oscillator,
  osc_triggerable: zang.Triggerable(zang.Oscillator),
  gate: zang.Gate,
  gate_triggerable: zang.Triggerable(zang.Gate),
  note_tracker: zang.NoteTracker,

  pub fn init() CoinVoice {
    return CoinVoice {
      .osc = zang.Oscillator.init(.Square),
      .osc_triggerable = zang.Triggerable(zang.Oscillator).init(),
      .gate = zang.Gate.init(),
      .gate_triggerable = zang.Triggerable(zang.Gate).init(),
      .note_tracker = zang.NoteTracker.init([]zang.SongNote {
        zang.SongNote{ .freq = 750.0, .t = 0.0 },
        zang.SongNote{ .freq = 1000.0, .t = 0.045 },
        zang.SongNote{ .freq = null, .t = 0.090 },
      }),
    };
  }

  pub fn paint(self: *CoinVoice, sample_rate: f32, out: []f32, note_on: bool, freq: f32, tmp: [2][]f32) void {
    const impulses = self.note_tracker.getImpulses(sample_rate, out.len, freq);

    zang.zero(tmp[0]);
    self.osc_triggerable.paintFromImpulses(&self.osc, sample_rate, tmp[0], impulses, [0][]f32{});
    zang.zero(tmp[1]);
    self.gate_triggerable.paintFromImpulses(self.gate, sample_rate, tmp[1], impulses, [0][]f32{});
    zang.multiplyWithScalar(tmp[1], 0.2);
    zang.multiply(out, tmp[0], tmp[1]);
  }

  pub fn reset(self: *CoinVoice) void {
    self.osc.reset();
    self.gate.reset();
    self.note_tracker.reset();
  }
};
