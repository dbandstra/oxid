use @import("platform/math3d.zig"); // FIXME
const c = @import("platform/c.zig"); // FIXME

pub const Transform = enum {
  Identity,
  FlipHorizontal,
  FlipVertical,
  RotateClockwise,
  RotateCounterClockwise,
};

pub const SolidParams = struct {
  color: Vec4,
};

pub const OutlineParams = struct {
  color: Vec4,
};

pub const TexturedParams = struct {
  tex_id: c.GLuint, // FIXME
  transform: Transform,
};

pub const RectStyle = union(enum) {
  Solid: SolidParams,
  Outline: OutlineParams,
  Textured: TexturedParams,
};
