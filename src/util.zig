pub fn lessThanField(comptime T: type, comptime field: []const u8) fn(T, T)bool {
  const impl = struct{
    fn inner(a: T, b: T) bool {
      return @field(a, field) < @field(b, field);
    }
  };

  return impl.inner;
}
