const std = @import("std");
const math = @import("../common/math.zig");

pub const SUBPIXELS_PER_PIXEL = 16;
pub const PIXELS_PER_TILE = 16;
pub const SUBPIXELS_PER_TILE = PIXELS_PER_TILE * SUBPIXELS_PER_PIXEL;

pub const TerrainType = enum {
    Floor,
    Wall,
    Pit, // blocks creatures but not bullets
};

pub fn getTerrainType(value: u8) TerrainType {
    if (value == 0x82) {
        return TerrainType.Pit;
    } else if ((value & 0x80) != 0) {
        return TerrainType.Wall;
    } else {
        return TerrainType.Floor;
    }
}

// this is generic only for testing purposes. all levels actually used in the
// game will be the same size
pub fn GenLevel(comptime w: u31, comptime h: u31) type {
    return struct {
        data: [w*h]u8,

        pub fn init(data: [w*h]u8) @This() {
            return @This() {
                .data = data,
            };
        }

        // currently unused
        pub fn posInWall(self: *const @This(), pos: math.Vec2) bool {
            const x = pos.x;
            const y = pos.y;

            const gx0 = @divFloor(x, SUBPIXELS_PER_TILE);
            const gy0 = @divFloor(y, SUBPIXELS_PER_TILE);
            const offx = @mod(x, SUBPIXELS_PER_TILE) != 0;
            const offy = @mod(y, SUBPIXELS_PER_TILE) != 0;

            return
                self.gridIsWall(gx0, gy0) or
                (offx and self.grid_is_wall(gx0 + 1, gy0)) or
                (offy and self.grid_is_wall(gx0, gy0 + 1)) or
                (offx and offy and self.grid_is_wall(gx0 + 1, gy0 + 1));
        }

        pub fn absBoxInWall(self: *const @This(), bbox: math.BoundingBox, ignore_pits: bool) bool {
            std.debug.assert(bbox.mins.x < bbox.maxs.x and bbox.mins.y < bbox.maxs.y);

            const gx0 = @divFloor(bbox.mins.x, SUBPIXELS_PER_TILE);
            const gy0 = @divFloor(bbox.mins.y, SUBPIXELS_PER_TILE);
            const gx1 = @divFloor(bbox.maxs.x, SUBPIXELS_PER_TILE);
            const gy1 = @divFloor(bbox.maxs.y, SUBPIXELS_PER_TILE);

            var gy: i32 = gy0;
            while (gy <= gy1) : (gy += 1) {
                var gx: i32 = gx0;
                while (gx <= gx1) : (gx += 1) {
                    if (self.getGridValue(math.Vec2.init(gx, gy))) |value| {
                        const tt = getTerrainType(value);
                        if (tt == TerrainType.Wall or (!ignore_pits and tt == TerrainType.Pit)) {
                            return true;
                        }
                    }
                }
            }

            return false;
        }

        pub fn boxInWall(self: *const @This(), pos: math.Vec2, bbox: math.BoundingBox, ignore_pits: bool) bool {
            return absBoxInWall(self, math.BoundingBox.move(bbox, pos), ignore_pits);
        }

        pub fn getGridValue(self: *const @This(), pos: math.Vec2) ?u8 {
            if (pos.x >= 0 and pos.y >= 0) {
                const x = @intCast(usize, pos.x);
                const y = @intCast(usize, pos.y);

                if (x < w and y < h) {
                    return self.data[y * w + x];
                }
            }

            return null;
        }

        pub fn getGridTerrainType(self: *const @This(), pos: math.Vec2) TerrainType {
            if (self.getGridValue(pos)) |value| {
                return getTerrainType(value);
            } else {
                return TerrainType.Wall;
            }
        }
    };
}

pub const W: u31 = 20;
pub const H: u31 = 14;

pub const Level = GenLevel(W, H);

pub const LEVEL1 = Level.init(blk: {
    const e = 0x00;
    const O = 0x80;
    const U = 0x81;
    // const x = 0x82; // pit
    const A = 0x83;
    const B = 0x84;
    const C = 0x85;
    const D = 0x86;

    break :blk [_]u8{
        O,U,U,U,U,U,U,U,U,U,U,U,O,U,U,U,U,U,U,O,
        O,e,e,e,e,e,e,e,e,e,e,e,O,e,e,e,e,e,e,O,
        O,e,A,B,e,O,U,e,U,U,O,e,U,e,U,e,A,B,e,O,
        O,e,C,D,e,O,e,e,e,e,O,e,e,e,e,e,C,D,e,O,
        O,e,e,e,e,U,e,U,U,e,U,e,U,U,O,e,e,e,e,O,
        O,O,e,O,e,e,e,e,e,e,e,e,e,e,U,e,U,U,e,O,
        O,U,e,U,U,U,e,O,e,O,O,e,O,e,e,e,e,e,e,O,
        O,e,e,e,e,e,e,U,e,U,U,e,U,e,U,U,O,e,O,O,
        O,e,U,U,e,O,e,e,e,e,e,e,e,e,e,e,U,e,U,O,
        O,e,e,e,e,U,U,U,e,O,e,U,U,e,O,e,e,e,e,O,
        O,e,A,B,e,e,e,e,e,O,e,e,e,e,O,e,A,B,e,O,
        O,e,C,D,e,U,e,O,e,U,U,U,e,U,U,e,C,D,e,O,
        O,e,e,e,e,e,e,O,e,e,e,e,e,e,e,e,e,e,e,O,
        O,O,O,O,O,O,O,O,O,O,O,O,O,O,O,O,O,O,O,O,
    };
});
