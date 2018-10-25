pub use @cImport({
  @cInclude("SDL2/SDL.h");
  @cInclude("epoxy/gl.h");
});

fn getPtrType(comptime T: type) type {
  const info = @typeInfo(T).Pointer;
  return if (info.is_const) ?[*]const info.child else ?[*]info.child;
}

// taken from tetris
// see https://github.com/ziglang/zig/issues/1059
pub fn ptr(p: var) getPtrType(@typeOf(p)) {
  return @ptrCast(getPtrType(@typeOf(p)), p);
}
