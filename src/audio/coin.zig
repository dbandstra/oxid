const zang = @import("zang");

pub const CoinVoice = struct {
  pub const NumOutputs = 1;
  pub const NumInputs = 0;
  pub const NumTemps = 2;
  pub const Params = struct { freq_mul: f32 };
  pub const InnerParams = struct { freq: f32, note_on: bool };

  pub const SoundDuration = 2.0;

  const Notes = zang.Notes(Params);
  const InnerNotes = zang.Notes(InnerParams);

  osc: zang.Triggerable(zang.PulseOsc),
  env: zang.Triggerable(zang.Envelope),
  note_tracker: InnerNotes.NoteTracker,

  pub fn init() CoinVoice {
    return CoinVoice {
      .osc = zang.initTriggerable(zang.PulseOsc.init()),
      .env = zang.initTriggerable(zang.Envelope.init(zang.EnvParams {
        .attack_duration = 0.0,
        .decay_duration = 0.0,
        .sustain_volume = 1.0,
        .release_duration = 0.04,
      })),
      .note_tracker = InnerNotes.NoteTracker.init([]InnerNotes.SongNote {
        InnerNotes.SongNote { .params = InnerParams { .freq = 750.0, .note_on = true }, .t = 0.0 },
        InnerNotes.SongNote { .params = InnerParams { .freq = 1000.0, .note_on = true }, .t = 0.045 },
        InnerNotes.SongNote { .params = InnerParams { .freq = 1000.0, .note_on = false }, .t = 0.090 },
      }),
    };
  }

  pub fn reset(self: *CoinVoice) void {
    self.osc.reset();
    self.env.reset();
    self.note_tracker.reset();
  }

  pub fn paintSpan(self: *CoinVoice, sample_rate: f32, outputs: [NumOutputs][]f32, inputs: [NumInputs][]f32, temps: [NumTemps][]f32, params: Params) void {
    const out = outputs[0];
    const impulses = self.note_tracker.getImpulses(sample_rate, out.len);

    zang.zero(temps[0]);
    {
      var conv = zang.ParamsConverter(InnerParams, zang.PulseOsc.Params).init();
      for (conv.getPairs(impulses)) |*pair| {
        pair.dest = zang.PulseOsc.Params {
          .freq = pair.source.freq * params.freq_mul,
          .colour = 0.5,
        };
      }
      self.osc.paintFromImpulses(sample_rate, [1][]f32{temps[0]}, [0][]f32{}, [0][]f32{}, conv.getImpulses());
    }
    zang.zero(temps[1]);
    {
      var conv = zang.ParamsConverter(InnerParams, zang.Envelope.Params).init();
      self.env.paintFromImpulses(sample_rate, [1][]f32{temps[1]}, [0][]f32{}, [0][]f32{}, conv.autoStructural(impulses));
    }
    zang.multiplyWithScalar(temps[1], 0.2);
    zang.multiply(out, temps[0], temps[1]);
  }
};
