const std = @import("std");
const Seekable = @import("../../zigutils/src/traits/Seekable.zig").Seekable;
const RWops = @import("rwops.zig").RWops;
const c = @import("c.zig");
const Platform = @import("platform.zig");
const mix = @import("audio_mix.zig");

const MAX_SAMPLES = 20;
const NUM_SLOTS = 8;

pub const AudioSample = struct.{
  spec: c.SDL_AudioSpec,
  buf: []u8,
};

pub const AudioSlot = struct.{
  sample: ?*const AudioSample,
  position: usize,
  started_tickcount: usize,
};

pub const AudioState = struct.{
  device: c.SDL_AudioDeviceID,

  samples: [MAX_SAMPLES]AudioSample,
  num_samples: u32,

  slots: [NUM_SLOTS]AudioSlot,

  muted: bool,
  speed: usize,

  tickcount: usize,

  allocator: *std.mem.Allocator,
  mix_buffer: []i32,
};

// terminology:
// "sample": amplitude of one channel at one point in time
// "frame": a sample per channel
// for example, in 16-bit stereo, a sample is 2 bytes and a frame is 4 bytes
pub extern fn audioCallback(userdata_: ?*c_void, stream_: ?[*]u8, len_: c_int) void {
  const as = @ptrCast(*AudioState, @alignCast(@alignOf(*AudioState), userdata_.?));
  const stream = stream_.?[0..@intCast(usize, len_)];

  const frames_per_tick = 44100 / 60; // FIXME - no magic numbers
  const bytes_per_frame = 2; // ditto

  std.debug.assert(as.mix_buffer.len * 2 == stream.len);
  std.debug.assert((as.mix_buffer.len % bytes_per_frame) == 0);

  std.mem.set(i32, as.mix_buffer, 0);

  for (as.slots) |*slot| {
    if (slot.sample) |sample| {
      var skip_frames: usize = 0;

      if (slot.position == 0) {
        // sound hasn't started playing yet. calculate how far into the mix
        // buffer the sound should start playing.
        // fudge the started_tickcount back by one in order to be optimistic,
        // and because there's probably a bit of delay involved in everything
        const started_tickcount =
          if (slot.started_tickcount > 0) slot.started_tickcount - 1 else 0;

        skip_frames = std.math.min(
          frames_per_tick * started_tickcount,
          // clamp to one sample before the end of the mix buffer, so it's
          // guaranteed to start playing in this call
          as.mix_buffer.len - 1,
        );
      }

      slot.position += mix.mixAudio(
        as.mix_buffer[skip_frames..],
        sample.buf[slot.position..],
        as.muted,
        as.speed,
      );

      if (slot.position >= sample.buf.len) {
        slot.* = AudioSlot.{
          .sample = null,
          .position = 0,
          .started_tickcount = 0,
        };
      }
    }
  }

  mix.mixDown(stream, as.mix_buffer);

  as.tickcount = 0;
}

fn clearState(as: *AudioState) void {
  as.num_samples = 0;

  for (as.slots[0..NUM_SLOTS]) |*slot| {
    slot.* = AudioSlot.{
      .sample = null,
      .position = 0,
      .started_tickcount = 0,
    };
  }

  as.muted = false;
  as.speed = 1;

  as.tickcount = 0;
}

pub fn init(as: *AudioState, params: Platform.InitParams, device: c.SDL_AudioDeviceID) error!void {
  as.device = device;

  c.SDL_LockAudioDevice(as.device);
  defer c.SDL_UnlockAudioDevice(as.device);

  as.allocator = &params.dsaf.high_allocator;
  as.mix_buffer = try as.allocator.alloc(i32, params.audio_buffer_size);

  clearState(as);
}

pub fn deinit(as: *AudioState) void {
  c.SDL_LockAudioDevice(as.device);
  defer c.SDL_UnlockAudioDevice(as.device);

  for (as.samples[0..as.num_samples]) |*sample| {
    c.SDL_FreeWAV(c.ptr(sample.buf.ptr));
  }

  clearState(as);

  as.allocator.free(as.mix_buffer);
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
  var buf: [*]u8 = undefined;
  var len: u32 = undefined;
  const actual = c.SDL_LoadWAV_RW(
    rwops_ptr,
    0,
    @ptrCast([*]c.SDL_AudioSpec, &sample.spec),
    @ptrCast([*]?[*]u8, &buf),
    @ptrCast([*]u32, &len),
  );
  if (actual == null) {
    c.SDL_Log(c"SDL_LoadWAV failed: %s", c.SDL_GetError());
    return 0;
  }
  sample.buf = buf[0..len];
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
        slot.* = AudioSlot.{
          .sample = sample,
          .position = 0,
          .started_tickcount = ps.audio_state.tickcount,
        };
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

pub fn incrementTickCount(ps: *Platform.State, num_ticks: usize) void {
  c.SDL_LockAudioDevice(ps.audio_state.device);
  defer c.SDL_UnlockAudioDevice(ps.audio_state.device);

  ps.audio_state.tickcount += num_ticks;
  ps.audio_state.speed = num_ticks;
}
