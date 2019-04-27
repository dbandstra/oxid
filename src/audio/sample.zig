const zang = @import("zang");

// TODO - remove and just use zang.Sampler
pub const SampleVoice = struct {
  pub const NumOutputs = 1;
  pub const NumInputs = 0;
  pub const NumTemps = 0;
  pub const Params = struct {
    wav: zang.WavContents,
  };

  pub const SoundDuration = 2.0; // hack

  const Notes = zang.Notes(Params);

  sampler: zang.Sampler,

  pub fn init() SampleVoice {
    return SampleVoice {
      .sampler = zang.Sampler.init(),
    };
  }

  pub fn reset(self: *SampleVoice) void {
    self.sampler.reset();
  }

  pub fn paintSpan(self: *SampleVoice, sample_rate: f32, outputs: [NumOutputs][]f32, inputs: [NumInputs][]f32, temps: [NumTemps][]f32, params: Params) void {
    self.sampler.paintSpan(sample_rate, outputs, inputs, temps, zang.Sampler.Params {
      .freq = 1.0,
      .sample_data = params.wav.data,
      .sample_rate = @intToFloat(f32, params.wav.sample_rate),
      .sample_freq = null,
    });
  }
};
