const c = @import("c.zig");
const Platform = @import("platform.zig");

pub const AudioState = struct{
  device: c.SDL_AudioDeviceID,
  frequency: u32,

  muted: bool,
  speed: u32,
};

pub fn init(as: *AudioState, params: Platform.InitParams, device: c.SDL_AudioDeviceID) anyerror!void {
  lockAudio(as);
  defer unlockAudio(as);

  as.device = device;
  as.frequency = params.audio_frequency;

  as.muted = false;
  as.speed = 1;
}

pub fn deinit(as: *AudioState) void {
  lockAudio(as);
  defer unlockAudio(as);
}

pub fn setMute(as: *AudioState, mute: bool) void {
  lockAudio(as);
  defer unlockAudio(as);

  as.muted = mute;
}

pub fn setAudioSpeed(as: *AudioState, num_ticks: u32) void {
  lockAudio(as);
  defer unlockAudio(as);

  as.speed = num_ticks;
}

pub fn lockAudio(as: *AudioState) void {
  c.SDL_LockAudioDevice(as.device);
}

pub fn unlockAudio(as: *AudioState) void {
  c.SDL_UnlockAudioDevice(as.device);
}
