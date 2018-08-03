const std = @import("std");
const c = @import("c.zig");
const Seekable = @import("../../zigutils/src/traits/Seekable.zig").Seekable;

pub fn RWops(comptime ReadError: type) type {
  return struct{
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
      const size = seekable.getEndPos() catch return -1;
      return @intCast(i64, size);
    }

    extern fn seekFn(context: ?[*]c.SDL_RWops, offset: i64, whence: c_int) i64 {
      var seekable = getSeekable(context);

      switch (whence) {
        c.RW_SEEK_SET => {
          if (offset < 0) return -1;
          const uofs = @intCast(usize, offset);
          seekable.seekTo(uofs) catch return -1;
        },
        c.RW_SEEK_CUR => {
          const pos = seekable.getPos() catch return -1;
          const new_ofs = @intCast(i64, pos) + offset;
          const new_ofs2 = @intCast(usize, new_ofs);
          seekable.seekTo(new_ofs2) catch return -1;
        },
        c.RW_SEEK_END => {
          if (offset < 0) return -1;
          const end = seekable.getEndPos() catch return -1;
          const uofs = @intCast(usize, offset);
          seekable.seekTo(end - uofs) catch return -1;
        },
        else => {
          return -1;
        },
      }
      const pos = seekable.getPos() catch return -1;
      return @intCast(i64, pos);
    }

    extern fn readFn(context: ?[*]c.SDL_RWops, ptr_: ?*c_void, size: usize, maxnum: usize) usize {
      var in_stream = getInStream(context);

      const ptr = ptr_ orelse return 0;

      const num_bytes = size * maxnum;

      var ptr2 = @ptrCast([*]u8, ptr);
      var slice = ptr2[0..num_bytes];

      if (in_stream.read(slice)) |n| {
        // FIXME!!! this function is supposed to return number of elements (a
        // multiple of `size`).
        // the in_stream.read may return an incomplete read (e.g. if it's
        // coming from a buffered instream), but because it only cares about
        // bytes, not "elements", it could stop in the middle of an element...
        // i guess i should detect that and then seek back to the beginning of
        // the fragmented element? not sure what else i could do other than
        // holding an at-least-one-element-big buffer in this object
        if (n != num_bytes) {
          @panic("FIXME!!!!"); // FIXME!!!!
        }
        return maxnum;
      } else |err| {
        std.debug.warn("bye {}\n", err);
        // TODO call SDL_SetError
        return 0;
      }
    }

    extern fn writeFn(context: ?[*]c.SDL_RWops, ptr_: ?*const c_void, size: usize, num: usize) usize {
      return 0; // error or eof
    }

    extern fn closeFn(context: ?[*]c.SDL_RWops) c_int {
      return 0; // successful
    }
  };
}
