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
pub fn mixAudio(dst: []u8, src: []const u8) void {
  const max_audioval: i32 = ((1 << (16 - 1)) - 1);
  const min_audioval: i32 = -(1 << (16 - 1));

  var num_samples = std.math.min(dst.len, src.len) / 2;

  var i: usize = 0; while (i < num_samples * 2) : (i += 2) {
    const src_sample = i16(src[i]) | (i16(src[i + 1]) << 8);
    const dst_sample = i16(dst[i]) | (i16(dst[i + 1]) << 8);

    const new_sample = i32(dst_sample) + @divTrunc(i32(src_sample), 2); // 50% volume

    const clamped_sample =
      if (new_sample < min_audioval)
        min_audioval
      else if (new_sample > max_audioval)
        max_audioval
      else
        new_sample;

    dst[i] = @intCast(u8, clamped_sample & 0xFF);
    dst[i + 1] = @intCast(u8, (clamped_sample >> 8) & 0xFF);
  }
}
