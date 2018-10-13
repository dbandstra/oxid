pub use @cImport({
  @cInclude("SDL2/SDL.h");
  @cInclude("SDL2/SDL_mixer.h");
  @cInclude("epoxy/gl.h");
});

// taken from tetris
// see https://github.com/ziglang/zig/issues/1059
pub fn ptr(p: var) t: {
  const T = @typeOf(p);
  const info = @typeInfo(@typeOf(p)).Pointer;
  break :t if (info.is_const) ?[*]const info.child else ?[*]info.child;
} {
  const ReturnType = t: {
    const T = @typeOf(p);
    const info = @typeInfo(@typeOf(p)).Pointer;
    break :t if (info.is_const) ?[*]const info.child else ?[*]info.child;
  };
  return @ptrCast(ReturnType, p);
}
