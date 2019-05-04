const zang = @import("zang");

pub const Instrument = struct {
  pub const NumOutputs = 1;
  pub const NumTemps = 2;
  pub const Params = struct { freq: f32, note_on: bool };

  osc: zang.PulseOsc,
  env: zang.Envelope,

  pub fn init() Instrument {
    return Instrument {
      .osc = zang.PulseOsc.init(),
      .env = zang.Envelope.init(zang.EnvParams {
        .attack_duration = 0.0,
        .decay_duration = 0.0,
        .sustain_volume = 1.0,
        .release_duration = 0.04,
      }),
    };
  }

  pub fn reset(self: *Instrument) void {
    self.osc.reset();
    self.env.reset();
  }

  pub fn paint(self: *Instrument, sample_rate: f32, outputs: [NumOutputs][]f32, temps: [NumTemps][]f32, params: Params) void {
    zang.zero(temps[0]);
    self.osc.paint(sample_rate, [1][]f32{temps[0]}, [0][]f32{}, zang.PulseOsc.Params {
      .freq = params.freq,
      .colour = 0.5,
    });
    zang.zero(temps[1]);
    self.env.paint(sample_rate, [1][]f32{temps[1]}, [0][]f32{}, zang.Envelope.Params {
      .note_on = params.note_on,
    });
    zang.multiplyWithScalar(temps[1], 0.25);
    zang.multiply(outputs[0], temps[0], temps[1]);
  }
};

pub const CoinVoice = struct {
  pub const NumOutputs = 1;
  pub const NumTemps = 2;
  pub const Params = struct { freq_mul: f32 };

  pub const SoundDuration = 2.0;

  instrument: zang.Triggerable(Instrument),
  note_tracker: zang.Notes(Instrument.Params).NoteTracker,

  pub fn init() CoinVoice {
    const SongNote = zang.Notes(Instrument.Params).SongNote;

    return CoinVoice {
      .instrument = zang.initTriggerable(Instrument.init()),
      .note_tracker = zang.Notes(Instrument.Params).NoteTracker.init([]SongNote {
        SongNote { .params = Instrument.Params { .freq = 750.0, .note_on = true }, .t = 0.0 },
        SongNote { .params = Instrument.Params { .freq = 1000.0, .note_on = true }, .t = 0.045 },
        SongNote { .params = Instrument.Params { .freq = 1000.0, .note_on = false }, .t = 0.090 },
      }),
    };
  }

  pub fn reset(self: *CoinVoice) void {
    self.instrument.reset();
    self.note_tracker.reset();
  }

  pub fn paint(self: *CoinVoice, sample_rate: f32, outputs: [NumOutputs][]f32, temps: [NumTemps][]f32, params: Params) void {
    for (self.note_tracker.begin(sample_rate, outputs[0].len)) |*impulse| {
      impulse.note.params.freq *= params.freq_mul;
    }
    self.instrument.paintFromImpulses(sample_rate, outputs, temps, self.note_tracker.finish());
  }
};
