// Simple DirectMedia Layer
// Copyright (C) 1997-2018 Sam Lantinga <slouken@libsdl.org>
// This software is provided 'as-is', without any express or implied
// warranty.  In no event will the authors be held liable for any damages
// arising from the use of this software.
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source distribution.

const std = @import("std");

// adapted from SDL2's SDL_MixAudioFormat function (AUDIO_S16LSB format)
// `speed` is like a stride for the src buffer.
// returns the number of source bytes used
pub fn mixAudio(dst: []u8, src: []const u8, muted: bool, speed: usize) usize {
  // since this is 16-bit audio, make sure both buffers have even length
  std.debug.assert((dst.len % 1) == 0);
  std.debug.assert((src.len % 1) == 0);

  const num_bytes = std.math.min(dst.len, src.len);

  if (!muted) {
    const max_audioval: i32 = std.math.maxInt(i16);
    const min_audioval: i32 = std.math.minInt(i16);

    var i: usize = 0; while (i < num_bytes) : (i += 2) {
      var dst_sample: i32 = i16(dst[i]) | (i16(dst[i + 1]) << 8);

      var cumul: i32 = 0;

      var j: usize = 0; while (j < speed) : (j += 1) {
        const src_index = i * speed + j * 2;
        if (src_index >= src.len) {
          break;
        }

        cumul += i16(src[src_index]) | (i16(src[src_index + 1]) << 8);
      }

      // average out all the source samples, and cut to 50% volume
      dst_sample += @divTrunc(cumul, 2 * @intCast(i32, speed));

      const clamped_sample =
        if (dst_sample < min_audioval)
          min_audioval
        else if (dst_sample > max_audioval)
          max_audioval
        else
          dst_sample;

      dst[i] = @intCast(u8, clamped_sample & 0xFF);
      dst[i + 1] = @intCast(u8, (clamped_sample >> 8) & 0xFF);
    }
  }

  return num_bytes * speed;
}
