const std = @import("std");

// `speed` is like a stride for the src buffer.
// returns the number of source bytes used
pub fn mixAudio(dst: []i32, src: []const u8, muted: bool, speed: usize) usize {
  std.debug.assert(speed > 0);

  // since this is 16-bit audio, make sure the buffer has even length
  std.debug.assert((src.len % 1) == 0);

  const num_frames = std.math.min(dst.len, src.len / 2);

  if (!muted) {
    if (speed == 0) {
      var i: usize = 0; while (i < num_frames) : (i += 1) {
        dst[i] += i16(src[i * 2]) | (i16(src[i * 2 + 1]) << 8);
      }
    } else if (speed > 0) {
      // fast-forward mode: take the average of multiple source frames
      var i: usize = 0; while (i < num_frames) : (i += 1) {
        var cumul: i32 = 0;

        var src_i = i * speed * 2;
        const src_i_end = src_i + speed * 2;
        while (src_i < src_i_end and src_i < src.len) : (src_i += 2) {
          cumul += i16(src[src_i]) | (i16(src[src_i + 1]) << 8);
        }

        dst[i] += @divTrunc(cumul, @intCast(i32, speed));
      }
    }
  }

  return num_frames * 2 * speed;
}

// convert from 32-bit to 16-bit, applying clamping
pub fn mixDown(dst: []u8, mix_buffer: []i32) void {
  std.debug.assert(dst.len == mix_buffer.len * 2);

  const max_audioval: i32 = std.math.maxInt(i16);
  const min_audioval: i32 = std.math.minInt(i16);

  var i: usize = 0; while (i < mix_buffer.len) : (i += 1) {
    const value = @divTrunc(mix_buffer[i], 2); // also reduce volume to 50%

    const clamped_value =
      if (value < min_audioval)
        min_audioval
      else if (value > max_audioval)
        max_audioval
      else
        value;

    dst[i * 2 + 0] = @intCast(u8, clamped_value & 0xFF);
    dst[i * 2 + 1] = @intCast(u8, (clamped_value >> 8) & 0xFF);
  }
}
