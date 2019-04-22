const zang = @import("zang");

pub const WaveBeginVoice = struct {
  pub const NumTempBufs = 2;

  osc: zang.Oscillator,
  osc_trigger: zang.Trigger(zang.Oscillator),
  env: zang.Envelope,
  env_trigger: zang.Trigger(zang.Envelope),
  note_tracker: zang.NoteTracker,

  pub fn init() WaveBeginVoice {
    const speed = 0.125;

    return WaveBeginVoice {
      .osc = zang.Oscillator.init(.Square),
      .osc_trigger = zang.Trigger(zang.Oscillator).init(),
      .env = zang.Envelope.init(zang.EnvParams {
        .attack_duration = 0.01,
        .decay_duration = 0.1,
        .sustain_volume = 0.5,
        .release_duration = 0.15,
      }),
      .env_trigger = zang.Trigger(zang.Envelope).init(),
      .note_tracker = zang.NoteTracker.init([]zang.SongNote {
        zang.SongNote{ .freq = 40.0, .t = 0.0 * speed },
        zang.SongNote{ .freq = 43.0, .t = 1.0 * speed },
        zang.SongNote{ .freq = 36.0, .t = 2.0 * speed },
        zang.SongNote{ .freq = 45.0, .t = 3.0 * speed },
        zang.SongNote{ .freq = 43.0, .t = 4.0 * speed },
        zang.SongNote{ .freq = 36.0, .t = 5.0 * speed },
        zang.SongNote{ .freq = 40.0, .t = 6.0 * speed },
        zang.SongNote{ .freq = 45.0, .t = 7.0 * speed },
        zang.SongNote{ .freq = 43.0, .t = 8.0 * speed },
        zang.SongNote{ .freq = 35.0, .t = 9.0 * speed },
        zang.SongNote{ .freq = 38.0, .t = 10.0 * speed },
        zang.SongNote{ .freq = null, .t = 11.0 * speed },
      }),
    };
  }

  pub fn paint(self: *WaveBeginVoice, sample_rate: f32, out: []f32, note_on: bool, freq: f32, tmp: [2][]f32) void {
    const impulses = self.note_tracker.getImpulses(sample_rate / freq, out.len, null);

    zang.zero(tmp[0]);
    self.osc_trigger.paintFromImpulses(&self.osc, sample_rate, tmp[0], impulses, [0][]f32{});
    zang.zero(tmp[1]);
    self.env_trigger.paintFromImpulses(&self.env, sample_rate, tmp[1], impulses, [0][]f32{});
    zang.multiplyWithScalar(tmp[1], 0.25);
    zang.multiply(out, tmp[0], tmp[1]);
  }

  pub fn reset(self: *WaveBeginVoice) void {
    self.osc.reset();
    self.env.reset();
    self.note_tracker.reset();
  }
};
