const std = @import("std");
const Seekable = @import("../../zigutils/src/traits/Seekable.zig").Seekable;
const RWops = @import("rwops.zig").RWops;
const c = @import("c.zig");
const Platform = @import("platform.zig");

const MAX_SAMPLES = 20;
const NUM_SLOTS = 8;

pub const AudioSample = struct.{
  spec: c.SDL_AudioSpec,
  buf: [*]u8,
  len: u32, // num bytes
};

pub const AudioSlot = struct.{
  sample: ?*const AudioSample,
  position: u32,
};

pub const AudioState = struct.{
  device: c.SDL_AudioDeviceID,

  samples: [MAX_SAMPLES]AudioSample,
  num_samples: u32,

  slots: [NUM_SLOTS]AudioSlot,

  muted: bool,
};

pub extern fn audioCallback(userdata: ?*c_void, stream_: ?[*]u8, len: c_int) void {
  const stream = stream_ orelse return;

  _ = c.SDL_memset(stream, 0, @intCast(usize, len));

  const userdata_aligned = @alignCast(@alignOf(*AudioState), userdata.?);
  const as = @ptrCast(*AudioState, userdata_aligned);

  for (as.slots) |*slot| {
    if (slot.sample) |sample| {
      const ulen = @intCast(u32, len);
      const bytes_left = sample.len - slot.position;
      const num_bytes = if (bytes_left < ulen) bytes_left else ulen;

      if (!as.muted) {
        const bufPtr = @ptrToInt(sample.buf) + slot.position;

        // TODO - mix into a u32 buffer and clamp it once at the end?
        c.SDL_MixAudioFormat(
          stream, // dst
          @intToPtr([*]const u8, bufPtr), // src
          sample.spec.format, // format
          num_bytes, // num bytes
          c.SDL_MIX_MAXVOLUME / 2, // volume
        );
      }

      slot.position += num_bytes;
      if (slot.position >= sample.len) {
        slot.sample = null;
        slot.position = 0;
      }
    }
  }
}

fn clearState(as: *AudioState) void {
  as.num_samples = 0;

  for (as.slots[0..NUM_SLOTS]) |*slot| {
    slot.sample = null;
    slot.position = 0;
  }

  as.muted = false;
}

pub fn init(as: *AudioState, params: Platform.InitParams, device: c.SDL_AudioDeviceID) error!void {
  as.device = device;

  c.SDL_LockAudioDevice(as.device);
  defer c.SDL_UnlockAudioDevice(as.device);

  clearState(as);
}

pub fn deinit(as: *AudioState) void {
  c.SDL_LockAudioDevice(as.device);
  defer c.SDL_UnlockAudioDevice(as.device);

  for (as.samples[0..as.num_samples]) |*sample| {
    c.SDL_FreeWAV(c.ptr(sample.buf));
  }

  clearState(as);
}

// note: handle 0 is null/empty.
// handle 1 refers to chunks[0], etc.
// note: WAV will not be resampled. so if its frequency doesn't match the mix
// frequency, it will play at the wrong speed
pub fn loadSound(
  ps: *Platform.State,
  comptime ReadError: type,
  stream: *std.io.InStream(ReadError),
  seekable: *Seekable,
) u32 {
  c.SDL_LockAudioDevice(ps.audio_state.device);
  defer c.SDL_UnlockAudioDevice(ps.audio_state.device);

  if (ps.audio_state.num_samples == MAX_SAMPLES) {
    c.SDL_Log(c"no slots free to load sound");
    return 0;
  }
  var rwops = RWops(ReadError).create(stream, seekable);
  var rwops_ptr = @ptrCast([*]c.SDL_RWops, &rwops);

  var sample = &ps.audio_state.samples[ps.audio_state.num_samples];
  const actual = c.SDL_LoadWAV_RW(
    rwops_ptr,
    0,
    @ptrCast([*]c.SDL_AudioSpec, &sample.spec),
    @ptrCast([*]?[*]u8, &sample.buf),
    @ptrCast([*]u32, &sample.len),
  );
  if (actual == null) {
    c.SDL_Log(c"SDL_LoadWAV failed: %s", c.SDL_GetError());
    return 0;
  }
  // note: `actual` and `&sample.buf` are the same
  ps.audio_state.num_samples += 1;
  return ps.audio_state.num_samples;
}

pub fn playSound(ps: *Platform.State, handle: u32) void {
  c.SDL_LockAudioDevice(ps.audio_state.device);
  defer c.SDL_UnlockAudioDevice(ps.audio_state.device);

  if (handle > 0 and handle <= ps.audio_state.num_samples) {
    const sample = &ps.audio_state.samples[handle - 1];
    for (ps.audio_state.slots) |*slot| {
      if (slot.sample == null) {
        slot.sample = sample;
        slot.position = 0;
        break;
      }
    } else {
      // no free slot...
    }
  }
}

pub fn setMute(ps: *Platform.State, mute: bool) void {
  c.SDL_LockAudioDevice(ps.audio_state.device);
  defer c.SDL_UnlockAudioDevice(ps.audio_state.device);

  ps.audio_state.muted = mute;
}
