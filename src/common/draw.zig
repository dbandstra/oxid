const pdraw = @import("pdraw");

pub const Tileset = struct {
    texture: pdraw.Texture,
    xtiles: u32,
    ytiles: u32,
};

pub const Tile = struct {
    tx: u32,
    ty: u32,
};

pub const Transform = enum {
    identity,
    flip_horz,
    flip_vert,
    rotate_cw,
    rotate_ccw,
};

// FIXME - use the palette!
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub const white = Color{ .r = 255, .g = 255, .b = 255 };
pub const black = Color{ .r = 0, .g = 0, .b = 0 };

pub const SolidParams = struct {
    color: Color,
};

pub const OutlineParams = struct {
    color: Color,
};

pub const RectStyle = union(enum) {
    solid: SolidParams,
    outline: OutlineParams,
};
