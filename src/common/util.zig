const std = @import("std");
const builtin = @import("builtin");

pub fn lessThanField(comptime T: type, comptime field: []const u8) fn(T, T)bool {
  const Impl = struct{
    fn inner(a: T, b: T) bool {
      return @field(a, field) < @field(b, field);
    }
  };

  return Impl.inner;
}

// what should std.mem.readInt's behaviour be for an int type that's
// not a multiple of 8 bits?
// if you try to use it on something less than 8 bits, it causes a big
// compile error...
// i was getting this by calling rand.range() with a < 8 bit int type.
