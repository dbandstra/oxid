const zang = @import("zang");

pub const SampleVoice = struct {
  pub const NumTempBufs = 0;
  pub const SoundDuration = 2.0; // hack

  iq: zang.ImpulseQueue,
  trigger: zang.Trigger(SampleVoice),

  sampler: zang.Sampler,

  pub fn init() SampleVoice {
    return SampleVoice {
      .iq = zang.ImpulseQueue.init(),
      .trigger = zang.Trigger(SampleVoice).init(),
      .sampler = zang.Sampler.init([0]u8{}, 48000, 1.0),
    };
  }

  // FIXME sample should be a property of the impulse/note!!!
  pub fn setSample(self: *SampleVoice, wav: zang.WavContents) void {
    self.sampler.sample_data = wav.data;
    self.sampler.sample_rate = @intToFloat(f32, wav.sample_rate);
    self.sampler.reset();
  }

  pub fn paint(self: *SampleVoice, sample_rate: f32, out: []f32, note_on: bool, freq: f32, tmp: [0][]f32) void {
    self.sampler.paint(sample_rate, out, note_on, freq, tmp);
  }

  pub fn reset(self: *SampleVoice) void {
    self.sampler.reset();
  }
};
