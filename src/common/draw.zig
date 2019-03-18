const Platform = @import("platform/index.zig");

pub const Tileset = struct{
  texture: Platform.Texture,
  xtiles: u32,
  ytiles: u32,
};

pub const Tile = struct{
  tx: u32,
  ty: u32,
};

pub const Transform = enum{
  Identity,
  FlipHorizontal,
  FlipVertical,
  RotateClockwise,
  RotateCounterClockwise,
};

// FIXME - use the palette!
pub const Color = struct{
  r: u8,
  g: u8,
  b: u8,
  a: u8,
};

pub const SolidParams = struct{
  color: Color,
};

pub const OutlineParams = struct{
  color: Color,
};

pub const RectStyle = union(enum){
  Solid: SolidParams,
  Outline: OutlineParams,
};
