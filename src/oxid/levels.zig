const build_options = @import("build_options");
const std = @import("std");
const pcx = @import("zig-pcx");
const math = @import("../common/math.zig");
const graphics = @import("graphics.zig");

pub const subpixels_per_pixel = 16;
pub const pixels_per_tile = 16;
pub const subpixels_per_tile = pixels_per_tile * subpixels_per_pixel;

pub const TerrainType = enum {
    floor,
    wall,
};

pub const MapTile = struct {
    graphic: graphics.Graphic,
    terrain_type: TerrainType,
    foreground: bool,
};

pub const width = 20;
pub const height = 14;

pub const Level = struct {
    tiles: [width * height]MapTile,
};

pub fn absBoxInWall(level: Level, bbox: math.Box) bool {
    std.debug.assert(bbox.mins.x < bbox.maxs.x and bbox.mins.y < bbox.maxs.y);

    const gx0 = @divFloor(bbox.mins.x, subpixels_per_tile);
    const gy0 = @divFloor(bbox.mins.y, subpixels_per_tile);
    const gx1 = @divFloor(bbox.maxs.x, subpixels_per_tile);
    const gy1 = @divFloor(bbox.maxs.y, subpixels_per_tile);

    var gy: i32 = gy0;
    while (gy <= gy1) : (gy += 1) {
        var gx: i32 = gx0;
        while (gx <= gx1) : (gx += 1) {
            // outside the map is considered wall
            const tile = getMapTile(level, gx, gy) orelse return true;
            if (tile.terrain_type == .wall)
                return true;
        }
    }

    return false;
}

pub fn boxInWall(level: Level, pos: math.Vec2, bbox: math.Box) bool {
    return absBoxInWall(level, math.moveBox(bbox, pos));
}

pub fn getMapTile(level: Level, x: i32, y: i32) ?MapTile {
    if (x >= 0 and y >= 0) {
        const ux = @intCast(usize, x);
        const uy = @intCast(usize, y);

        if (ux < width and uy < height) {
            return level.tiles[uy * width + ux];
        }
    }

    return null;
}

// levels are loaded from pcx files. the palette is thrown out but the color
// index of each pixel is meaningful
pub const level1 = Level{ .tiles = loadLevel("level1.pcx") };

// map of pcx indexed color values to level tile information
// zig fmt: off
const mapping = [_]MapTile{
    .{ .graphic = .floor,        .terrain_type = .floor, .foreground = false },
    .{ .graphic = .evilwall_bl,  .terrain_type = .wall,  .foreground = false },
    .{ .graphic = .evilwall_tl,  .terrain_type = .wall,  .foreground = false },
    .{ .graphic = .evilwall_tr,  .terrain_type = .wall,  .foreground = false },
    .{ .graphic = .wall2,        .terrain_type = .wall,  .foreground = false },
    .{ .graphic = .evilwall_br,  .terrain_type = .wall,  .foreground = false },
    .{ .graphic = .wall,         .terrain_type = .wall,  .foreground = false },
    .{ .graphic = .floor_shadow, .terrain_type = .floor, .foreground = false },
    .{ .graphic = .station_tl,   .terrain_type = .wall,  .foreground = true  },
    .{ .graphic = .station_tr,   .terrain_type = .wall,  .foreground = true  },
    .{ .graphic = .station_bl,   .terrain_type = .wall,  .foreground = true  },
    .{ .graphic = .station_br,   .terrain_type = .wall,  .foreground = true  },
    .{ .graphic = .station_sl,   .terrain_type = .floor, .foreground = false },
    .{ .graphic = .station_sr,   .terrain_type = .floor, .foreground = false },
};
// zig fmt: on

fn loadLevel(comptime filename: []const u8) [width * height]MapTile {
    @setEvalBranchQuota(20000);
    const input = @embedFile(build_options.assets_path ++ "/" ++ filename);
    var fbs = std.io.fixedBufferStream(input);
    var reader = fbs.reader();
    const Loader = pcx.Loader(@TypeOf(reader));
    const preloaded = try Loader.preload(&reader);
    if (preloaded.width != width or preloaded.height != height) {
        @compileError(filename ++ " does not match expected dimensions");
    }
    var pixels: [width * height]u8 = undefined;
    var tiles: [width * height]MapTile = undefined;
    try Loader.loadIndexed(&reader, preloaded, &pixels, null);
    for (pixels) |value, i| {
        tiles[i] = mapping[value];
    }
    return tiles;
}
