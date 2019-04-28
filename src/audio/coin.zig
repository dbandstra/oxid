const zang = @import("zang");

pub const CoinVoice = struct {
  pub const NumOutputs = 1;
  pub const NumInputs = 0;
  pub const NumTemps = 2;
  pub const Params = struct { freq_mul: f32 };
  pub const InnerParams = struct { freq: f32, note_on: bool };

  pub const SoundDuration = 0.09;

  const Notes = zang.Notes(Params);
  const InnerNotes = zang.Notes(InnerParams);

  osc: zang.Triggerable(zang.Oscillator),
  gate: zang.Triggerable(zang.Gate),
  note_tracker: InnerNotes.NoteTracker,

  pub fn init() CoinVoice {
    return CoinVoice {
      .osc = zang.initTriggerable(zang.Oscillator.init()),
      .gate = zang.initTriggerable(zang.Gate.init()),
      .note_tracker = InnerNotes.NoteTracker.init([]InnerNotes.SongNote {
        InnerNotes.SongNote { .params = InnerParams { .freq = 750.0, .note_on = true }, .t = 0.0 },
        InnerNotes.SongNote { .params = InnerParams { .freq = 1000.0, .note_on = true }, .t = 0.045 },
        InnerNotes.SongNote { .params = InnerParams { .freq = 1000.0, .note_on = false }, .t = 0.090 },
      }),
    };
  }

  pub fn reset(self: *CoinVoice) void {
    self.osc.reset();
    self.gate.reset();
    self.note_tracker.reset();
  }

  pub fn paintSpan(self: *CoinVoice, sample_rate: f32, outputs: [NumOutputs][]f32, inputs: [NumInputs][]f32, temps: [NumTemps][]f32, params: Params) void {
    const out = outputs[0];
    const impulses = self.note_tracker.getImpulses(sample_rate, out.len);

    zang.zero(temps[0]);
    {
      var conv = zang.ParamsConverter(InnerParams, zang.Oscillator.Params).init();
      for (conv.getPairs(impulses)) |*pair| {
        pair.dest = zang.Oscillator.Params {
          .waveform = .Square,
          .freq = pair.source.freq * params.freq_mul,
          .colour = 0.5,
        };
      }
      self.osc.paintFromImpulses(sample_rate, [1][]f32{temps[0]}, [0][]f32{}, [0][]f32{}, conv.getImpulses());
    }
    zang.zero(temps[1]);
    {
      var conv = zang.ParamsConverter(InnerParams, zang.Gate.Params).init();
      self.gate.paintFromImpulses(sample_rate, [1][]f32{temps[1]}, [0][]f32{}, [0][]f32{}, conv.autoStructural(impulses));
    }
    zang.multiplyWithScalar(temps[1], 0.2);
    zang.multiply(out, temps[0], temps[1]);
  }
};
