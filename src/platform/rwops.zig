const std = @import("std");
const c = @import("c.zig");
const Seekable = @import("../../zigutils/src/traits/Seekable.zig").Seekable;

pub fn RWops(comptime ReadError: type) type {
  return struct.{
    pub fn create(
      in_stream: *std.io.InStream(ReadError),
      seekable: *Seekable,
    ) c.SDL_RWops {
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

    fn getInStream(context: ?[*]c.SDL_RWops) *std.io.InStream(ReadError) {
      const context2 = @ptrCast(*c.SDL_RWops, context);
      const data = context2.hidden.unknown.data1;
      const data2 = @alignCast(@alignOf(*std.io.InStream(ReadError)), data);
      return @ptrCast(*std.io.InStream(ReadError), data2);
    }

    fn getSeekable(context: ?[*]c.SDL_RWops) *Seekable {
      const context2 = @ptrCast(*c.SDL_RWops, context);
      const data = context2.hidden.unknown.data2;
      const data2 = @alignCast(@alignOf(*Seekable), data);
      return @ptrCast(*Seekable, data2);
    }

    extern fn sizeFn(context: ?[*]c.SDL_RWops) i64 {
      var seekable = getSeekable(context);
      const pos = seekable.seek(0, Seekable.Whence.Current) catch return -1;
      const end_pos = seekable.seek(0, Seekable.Whence.End) catch return -1;
      _ = seekable.seek(pos, Seekable.Whence.Start) catch return -1;
      return end_pos;
    }

    extern fn seekFn(context: ?[*]c.SDL_RWops, offset: i64, whence: c_int) i64 {
      return getSeekable(context).seek(offset, switch (whence) {
        c.RW_SEEK_SET => Seekable.Whence.Start,
        c.RW_SEEK_CUR => Seekable.Whence.Current,
        c.RW_SEEK_END => Seekable.Whence.End,
        else => return -1,
      }) catch return -1;
    }

    extern fn readFn(context: ?[*]c.SDL_RWops, ptr: ?*c_void, size: usize, maxnum: usize) usize {
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

            _ = getSeekable(context).seek(-@intCast(i64, remainder), Seekable.Whence.Current) catch return 0;

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

    extern fn writeFn(context: ?[*]c.SDL_RWops, ptr_: ?*const c_void, size: usize, num: usize) usize {
      return 0; // error or eof
    }

    extern fn closeFn(context: ?[*]c.SDL_RWops) c_int {
      return 0; // successful
    }
  };
}
