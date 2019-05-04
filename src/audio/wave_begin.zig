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
        .attack_duration = 0.01,
        .decay_duration = 0.1,
        .sustain_volume = 0.5,
        .release_duration = 0.15,
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

pub const WaveBeginVoice = struct {
  pub const NumOutputs = 1;
  pub const NumTemps = 2;
  pub const Params = struct {};

  pub const SoundDuration = 2.0;

  instrument: zang.Triggerable(Instrument),
  note_tracker: zang.Notes(Instrument.Params).NoteTracker,

  pub fn init() WaveBeginVoice {
    const SongNote = zang.Notes(Instrument.Params).SongNote;
    const speed = 0.125;

    return WaveBeginVoice {
      .instrument = zang.initTriggerable(Instrument.init()),
      .note_tracker = zang.Notes(Instrument.Params).NoteTracker.init([]SongNote {
        SongNote { .params = Instrument.Params { .freq = 40.0, .note_on = true }, .t = 0.0 * speed },
        SongNote { .params = Instrument.Params { .freq = 43.0, .note_on = true }, .t = 1.0 * speed },
        SongNote { .params = Instrument.Params { .freq = 36.0, .note_on = true }, .t = 2.0 * speed },
        SongNote { .params = Instrument.Params { .freq = 45.0, .note_on = true }, .t = 3.0 * speed },
        SongNote { .params = Instrument.Params { .freq = 43.0, .note_on = true }, .t = 4.0 * speed },
        SongNote { .params = Instrument.Params { .freq = 36.0, .note_on = true }, .t = 5.0 * speed },
        SongNote { .params = Instrument.Params { .freq = 40.0, .note_on = true }, .t = 6.0 * speed },
        SongNote { .params = Instrument.Params { .freq = 45.0, .note_on = true }, .t = 7.0 * speed },
        SongNote { .params = Instrument.Params { .freq = 43.0, .note_on = true }, .t = 8.0 * speed },
        SongNote { .params = Instrument.Params { .freq = 35.0, .note_on = true }, .t = 9.0 * speed },
        SongNote { .params = Instrument.Params { .freq = 38.0, .note_on = true }, .t = 10.0 * speed },
        SongNote { .params = Instrument.Params { .freq = 38.0, .note_on = false }, .t = 11.0 * speed },
      }),
    };
  }

  pub fn reset(self: *WaveBeginVoice) void {
    self.instrument.reset();
    self.note_tracker.reset();
  }

  pub fn paint(self: *WaveBeginVoice, sample_rate: f32, outputs: [NumOutputs][]f32, temps: [NumTemps][]f32, params: Params) void {
    _ = self.note_tracker.begin(sample_rate, outputs[0].len);
    self.instrument.paintFromImpulses(sample_rate, outputs, temps, self.note_tracker.finish());
  }
};
