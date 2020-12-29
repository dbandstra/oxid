const pdraw = @import("root").pdraw;

pub const Tileset = struct {
    texture: pdraw.Texture,
    num_cols: u31,
    num_rows: u31,
    tile_w: u31,
    tile_h: u31,
};

pub const Tile = struct {
    tx: u31,
    ty: u31,
};

pub const Transform = enum {
    identity,
    flip_horz,
    flip_vert,
    rotate_cw,
    rotate_ccw,
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
};

pub const pure_white = Color{ .r = 255, .g = 255, .b = 255 };
pub const pure_black = Color{ .r = 0, .g = 0, .b = 0 };

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
