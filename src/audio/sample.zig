const build_options = @import("build_options");
const zang = @import("zang");

pub const SampleVoice = struct {
  iq: zang.ImpulseQueue,
  sampler: zang.Sampler,

  pub fn init(comptime filename: []const u8) !SampleVoice {
    var rate: u32 = undefined;

    const data = try zang.readWav(@embedFile(build_options.assets_path ++ "/" ++ filename), &rate);

    return SampleVoice{
      .iq = zang.ImpulseQueue.init(),
      .sampler = zang.Sampler.init(data, rate, 1.0),
    };
  }

  pub fn update(self: *SampleVoice, sample_rate: u32, out: []f32, frame_index: usize) void {
    if (!self.iq.isEmpty()) {
      self.sampler.paintFromImpulses(sample_rate, out, self.iq.getImpulses(), frame_index);
    }

    self.iq.flush(frame_index, out.len);
  }
};
