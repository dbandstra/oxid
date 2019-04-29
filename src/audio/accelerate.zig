const zang = @import("zang");

pub const AccelerateVoice = struct {
  pub const NumOutputs = 1;
  pub const NumInputs = 0;
  pub const NumTemps = 2;
  pub const Params = struct { playback_speed: f32 };
  pub const InnerParams = struct { freq: f32, note_on: bool };

  pub const SoundDuration = 2.0;

  const Notes = zang.Notes(Params);
  const InnerNotes = zang.Notes(InnerParams);

  osc: zang.Triggerable(zang.Oscillator),
  env: zang.Triggerable(zang.Envelope),
  note_tracker: InnerNotes.NoteTracker,

  pub fn init() AccelerateVoice {
    const speed = 0.125;

    return AccelerateVoice {
      .osc = zang.initTriggerable(zang.Oscillator.init()),
      .env = zang.initTriggerable(zang.Envelope.init(zang.EnvParams {
        .attack_duration = 0.01,
        .decay_duration = 0.1,
        .sustain_volume = 0.5,
        .release_duration = 0.15,
      })),
      .note_tracker = InnerNotes.NoteTracker.init([]InnerNotes.SongNote {
        // same as wave begin but with some notes chopped off
        InnerNotes.SongNote{ .params = InnerParams { .freq = 43.0, .note_on = true }, .t = 0.0 * speed },
        InnerNotes.SongNote{ .params = InnerParams { .freq = 36.0, .note_on = true }, .t = 1.0 * speed },
        InnerNotes.SongNote{ .params = InnerParams { .freq = 40.0, .note_on = true }, .t = 2.0 * speed },
        InnerNotes.SongNote{ .params = InnerParams { .freq = 45.0, .note_on = true }, .t = 3.0 * speed },
        InnerNotes.SongNote{ .params = InnerParams { .freq = 43.0, .note_on = true }, .t = 4.0 * speed },
        InnerNotes.SongNote{ .params = InnerParams { .freq = 35.0, .note_on = true }, .t = 5.0 * speed },
        InnerNotes.SongNote{ .params = InnerParams { .freq = 38.0, .note_on = true }, .t = 6.0 * speed },
        InnerNotes.SongNote{ .params = InnerParams { .freq = 38.0, .note_on = false }, .t = 7.0 * speed },
      }),
    };
  }

  pub fn reset(self: *AccelerateVoice) void {
    self.osc.reset();
    self.env.reset();
    self.note_tracker.reset();
  }

  pub fn paintSpan(self: *AccelerateVoice, sample_rate: f32, outputs: [NumOutputs][]f32, inputs: [NumInputs][]f32, temps: [NumTemps][]f32, params: Params) void {
    const out = outputs[0];
    const impulses = self.note_tracker.getImpulses(sample_rate / params.playback_speed, out.len);

    zang.zero(temps[0]);
    {
      var conv = zang.ParamsConverter(InnerParams, zang.Oscillator.Params).init();
      for (conv.getPairs(impulses)) |*pair| {
        pair.dest = zang.Oscillator.Params {
          .waveform = .Square,
          .freq = pair.source.freq * params.playback_speed,
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
    zang.multiplyWithScalar(temps[1], 0.25);
    zang.multiply(out, temps[0], temps[1]);
  }
};
