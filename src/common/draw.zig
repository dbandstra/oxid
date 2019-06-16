const platform = @import("../platform.zig");

pub const Tileset = struct {
    texture: platform.Texture,
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

// FIXME - use the palette!
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub const White = Color { .r = 255, .g = 255, .b = 255 };
pub const Black = Color { .r = 0, .g = 0, .b = 0 };

pub const SolidParams = struct {
    color: Color,
};

pub const OutlineParams = struct {
    color: Color,
};

pub const RectStyle = union(enum) {
    Solid: SolidParams,
    Outline: OutlineParams,
};
