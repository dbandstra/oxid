use @import("platform/math3d.zig"); // FIXME
const c = @import("platform/c.zig"); // FIXME
const Platform = @import("platform/platform.zig");

pub const Tileset = struct {
  texture: Platform.Texture,
  xtiles: u32,
  ytiles: u32,
};

pub const Tile = struct {
  tx: u32,
  ty: u32,
};

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

pub const RectStyle = union(enum) {
  Solid: SolidParams,
  Outline: OutlineParams,
};
