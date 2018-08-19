const std = @import("std");
const Seekable = @import("../../zigutils/src/traits/Seekable.zig").Seekable;
const RWops = @import("rwops.zig").RWops;
const c = @import("c.zig");
const Platform = @import("platform.zig");

const MAX_CHUNKS = 20;

pub const AudioState = struct{
  chunks: [MAX_CHUNKS][*]c.Mix_Chunk,
  num_chunks: u32,
};

pub fn init(as: *AudioState, params: *const Platform.InitParams) !void {
  // avoid overaggressive compile error (function must return an error)
  var zero: u32 = 0;

  if (zero == 1) {
    return error.FakeError;
  }
}

pub fn deinit(as: *AudioState) void {
  for (as.chunks[0..as.num_chunks]) |chunk| {
    c.Mix_FreeChunk(chunk);
  }
}

// note: handle 0 is null/empty.
// handle 1 refers to chunks[0], etc.
pub fn loadSound(
  ps: *Platform.State,
  comptime ReadError: type,
  stream: *std.io.InStream(ReadError),
  seekable: *Seekable,
) u32 {
  if (ps.audio_state.num_chunks == MAX_CHUNKS) {
    c.SDL_Log(c"no slots free to load sound");
    return 0;
  }
  var rwops = RWops(ReadError).create(stream, seekable);
  var rwops_ptr = @ptrCast([*]c.SDL_RWops, &rwops);
  const chunk = c.Mix_LoadWAV_RW(rwops_ptr, 0) orelse {
    c.SDL_Log(c"Mix_LoadWAV failed: %s", c.Mix_GetError());
    return 0;
  };
  ps.audio_state.chunks[ps.audio_state.num_chunks] = chunk;
  ps.audio_state.num_chunks += 1;
  return ps.audio_state.num_chunks;
}

pub fn playSound(ps: *Platform.State, handle: u32) void {
  const channel = -1;
  const loops = 0;
  const ticks = -1;
  if (handle > 0 and handle <= ps.audio_state.num_chunks) {
    const chunk = ps.audio_state.chunks[handle - 1];
    _ = c.Mix_PlayChannelTimed(channel, chunk, loops, ticks);
  }
}
