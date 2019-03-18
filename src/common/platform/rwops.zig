const std = @import("std");
const c = @import("c.zig");

pub fn RWops(
  comptime ReadError: type,
  comptime SeekErrorType: type,
  comptime GetSeekPosErrorType: type,
) type {
  const MyInStream = std.io.InStream(ReadError);
  const MySeekable = std.io.SeekableStream(SeekErrorType, GetSeekPosErrorType);

  return struct{
    pub fn create(in_stream: *MyInStream, seekable: *MySeekable) c.SDL_RWops {
      var rwops: c.SDL_RWops = undefined;

      rwops.type = 0;
      rwops.hidden.unknown.data1 = @ptrCast(*c_void, in_stream);
      rwops.hidden.unknown.data2 = @ptrCast(*c_void, seekable);
      rwops.size = sizeFn;
      rwops.seek = seekFn;
      rwops.read = readFn;
      rwops.write = writeFn;
      rwops.close = closeFn;

      return rwops;
    }

    fn getInStream(context: [*c]c.SDL_RWops) *MyInStream {
      const context2 = @ptrCast(*c.SDL_RWops, context);
      const data = context2.hidden.unknown.data1;
      const data2 = @alignCast(@alignOf(*MyInStream), data);
      return @ptrCast(*MyInStream, data2);
    }

    fn getSeekable(context: [*c]c.SDL_RWops) *MySeekable {
      const context2 = @ptrCast(*c.SDL_RWops, context);
      const data = context2.hidden.unknown.data2;
      const data2 = @alignCast(@alignOf(*MySeekable), data);
      return @ptrCast(*MySeekable, data2);
    }

    extern fn sizeFn(context: [*c]c.SDL_RWops) i64 {
      var seekable = getSeekable(context);
      const end_pos = seekable.getEndPos() catch return -1;
      return @intCast(i64, end_pos);
    }

    extern fn seekFn(context: [*c]c.SDL_RWops, ofs: i64, whence: c_int) i64 {
      var seekable = getSeekable(context);
      switch (whence) {
        c.RW_SEEK_SET => {
          const uofs = std.math.cast(usize, ofs) catch return -1;
          seekable.seekTo(uofs) catch return -1;
          return ofs;
        },
        c.RW_SEEK_CUR => {
          seekable.seekForward(ofs) catch return -1;
          const new_pos = seekable.getPos() catch return -1;
          const upos = std.math.cast(i64, new_pos) catch return -1;
          return upos;
        },
        c.RW_SEEK_END => {
          const end_pos = seekable.getEndPos() catch return -1;
          const end_upos = std.math.cast(i64, end_pos) catch return -1;
          if (-ofs > end_upos) return -1;
          const new_pos = end_upos + ofs;
          const new_upos = std.math.cast(usize, new_pos) catch return -1;
          seekable.seekTo(new_upos) catch return -1;
          return new_pos;
        },
        else => return -1,
      }
    }

    extern fn readFn(context: [*c]c.SDL_RWops, ptr: ?*c_void, size: usize, maxnum: usize) usize {
      var in_stream = getInStream(context);

      const num_bytes = size * maxnum;

      var slice = @ptrCast([*]u8, ptr)[0..num_bytes];
      var bytes_read: usize = 0;

      // fill the entire output buffer. since we have to return the number of
      // elements read, not the number of bytes, we can't stop reading in the
      // middle of an element. so just keep reading. the only edge case we need
      // to handle is if we hit EOF in the middle of an element
      while (bytes_read < num_bytes) {
        if (in_stream.read(slice[bytes_read..])) |n| {
          if (n == 0) {
            // hit the end of the stream - the caller was trying to read more
            // than was in the file.
            // return the number of whole elements read, and rewind any extra
            // bytes read (part of the next element).
            // warning: this code is untested
            const num_elements_read = bytes_read / maxnum;
            const remainder = bytes_read % maxnum;

            _ = getSeekable(context).seekForward(-@intCast(isize, remainder)) catch return 0;

            return num_elements_read;
          }
          bytes_read += n;
        } else |_| {
          // the read failed
          return 0;
        }
      }

      return maxnum;
    }

    extern fn writeFn(context: [*c]c.SDL_RWops, ptr_: ?*const c_void, size: usize, num: usize) usize {
      return 0; // error or eof
    }

    extern fn closeFn(context: [*c]c.SDL_RWops) c_int {
      return 0; // successful
    }
  };
}
