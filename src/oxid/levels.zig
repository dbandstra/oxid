const std = @import("std");
const math = @import("../common/math.zig");

pub const subpixels_per_pixel = 16;
pub const pixels_per_tile = 16;
pub const subpixels_per_tile = pixels_per_tile * subpixels_per_pixel;

pub const TerrainType = enum {
    floor,
    wall,
};

pub fn getTerrainType(value: u8) TerrainType {
    if ((value & 0x80) != 0) {
        return .wall;
    } else {
        return .floor;
    }
}

pub const width = 20;
pub const height = 14;

pub const Level = struct {
    data: [width * height]u8,

    pub fn init(data: [width * height]u8) Level {
        return .{
            .data = data,
        };
    }

    // currently unused
    pub fn posInWall(self: *const Level, pos: math.Vec2) bool {
        const x = pos.x;
        const y = pos.y;

        const gx0 = @divFloor(x, subpixels_per_tile);
        const gy0 = @divFloor(y, subpixels_per_tile);
        const offx = @mod(x, subpixels_per_tile) != 0;
        const offy = @mod(y, subpixels_per_tile) != 0;

        return
            self.gridIsWall(gx0, gy0) or
            (offx and self.grid_is_wall(gx0 + 1, gy0)) or
            (offy and self.grid_is_wall(gx0, gy0 + 1)) or
            (offx and offy and self.grid_is_wall(gx0 + 1, gy0 + 1));
    }

    pub fn absBoxInWall(self: *const Level, bbox: math.BoundingBox) bool {
        std.debug.assert(bbox.mins.x < bbox.maxs.x and bbox.mins.y < bbox.maxs.y);

        const gx0 = @divFloor(bbox.mins.x, subpixels_per_tile);
        const gy0 = @divFloor(bbox.mins.y, subpixels_per_tile);
        const gx1 = @divFloor(bbox.maxs.x, subpixels_per_tile);
        const gy1 = @divFloor(bbox.maxs.y, subpixels_per_tile);

        var gy: i32 = gy0;
        while (gy <= gy1) : (gy += 1) {
            var gx: i32 = gx0;
            while (gx <= gx1) : (gx += 1) {
                if (self.getGridValue(math.Vec2.init(gx, gy))) |value| {
                    const tt = getTerrainType(value);
                    if (tt == .wall) {
                        return true;
                    }
                }
            }
        }

        return false;
    }

    pub fn boxInWall(self: *const Level, pos: math.Vec2, bbox: math.BoundingBox) bool {
        return absBoxInWall(self, math.BoundingBox.move(bbox, pos));
    }

    pub fn getGridValue(self: *const Level, pos: math.Vec2) ?u8 {
        if (pos.x >= 0 and pos.y >= 0) {
            const x = @intCast(usize, pos.x);
            const y = @intCast(usize, pos.y);

            if (x < width and y < height) {
                return self.data[y * width + x];
            }
        }

        return null;
    }

    pub fn getGridTerrainType(self: *const Level, pos: math.Vec2) TerrainType {
        if (self.getGridValue(pos)) |value| {
            return getTerrainType(value);
        } else {
            return .wall;
        }
    }
};

// levels are loaded from pcx files. the palette is thrown out but the color
// index of each pixel is meaningful
pub const level1 = Level.init(loadLevel("level1.pcx"));

// map of pcx values to the values that are meaningful to the program
const mapping = [_]u8 {
    0x00, // floor
    0x85, // spooky block, bottom left
    0x83, // spooky block, top left
    0x84, // spooky block, top right
    0x81, // wall (south face)
    0x86, // spooky block, bottom right
    0x80, // wall
};

const build_options = @import("build_options");
const pcx = @import("zig-pcx");

fn loadLevel(comptime filename: []const u8) [width * height]u8 {
    @setEvalBranchQuota(20000);
    const input = @embedFile(build_options.assets_path ++ "/" ++ filename);
    var fbs = std.io.fixedBufferStream(input);
    var stream = fbs.inStream();
    const Loader = pcx.Loader(@TypeOf(stream));
    const preloaded = try Loader.preload(&stream);
    if (preloaded.width != width or preloaded.height != height) {
        @compileError(filename ++ " must be a 20x14 image");
    }
    var data: [width * height]u8 = undefined;
    try Loader.loadIndexed(&stream, preloaded, &data, null);
    for (data) |*v| {
        v.* = mapping[v.*];
    }
    return data;
}
