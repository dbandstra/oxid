const std = @import("std");
const builtin = @import("builtin");

pub fn lessThanField(comptime T: type, comptime field: []const u8) fn(T, T)bool {
  const impl = struct{
    fn inner(a: T, b: T) bool {
      return @field(a, field) < @field(b, field);
    }
  };

  return impl.inner;
}

pub fn randomEnumValue(comptime T: type, rand: *std.rand.Random) T {
  std.debug.assert(@typeId(T) == builtin.TypeId.Enum);
  const tag_type = @typeInfo(T).Enum.tag_type;
  const n = rand.range(u32, 0, @memberCount(T));
  const i = @intCast(tag_type, n);
  return @intToEnum(T, i);
}

// what should std.mem.readInt's behaviour be for an int type that's
// not a multiple of 8 bits?
// if you try to use it on something less than 8 bits, it causes a big
// compile error...
// i was getting this by calling rand.range() with a < 8 bit int type.
