const std = @import("std");
const math = @import("../common/math.zig");

pub const subpixels_per_pixel = 16;
pub const pixels_per_tile = 16;
pub const subpixels_per_tile = pixels_per_tile * subpixels_per_pixel;

pub const TerrainType = enum {
    floor,
    wall,
};

pub const width = 20;
pub const height = 14;

pub const Level = struct {
    data: [width * height]u8,
};

fn getTerrainType(value: u8) TerrainType {
    if ((value & 0x80) != 0) {
        return .wall;
    } else {
        return .floor;
    }
}

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
            if (getGridValue(level, math.vec2(gx, gy))) |value| {
                const tt = getTerrainType(value);
                if (tt == .wall) {
                    return true;
                }
            }
        }
    }

    return false;
}

pub fn boxInWall(level: Level, pos: math.Vec2, bbox: math.Box) bool {
    return absBoxInWall(level, math.moveBox(bbox, pos));
}

pub fn getGridValue(level: Level, pos: math.Vec2) ?u8 {
    if (pos.x >= 0 and pos.y >= 0) {
        const x = @intCast(usize, pos.x);
        const y = @intCast(usize, pos.y);

        if (x < width and y < height) {
            return level.data[y * width + x];
        }
    }

    return null;
}

pub fn getGridTerrainType(level: Level, pos: math.Vec2) TerrainType {
    if (getGridValue(level, pos)) |value| {
        return getTerrainType(value);
    } else {
        return .wall;
    }
}

// levels are loaded from pcx files. the palette is thrown out but the color
// index of each pixel is meaningful
pub const level1 = Level{ .data = loadLevel("level1.pcx") };

// map of pcx values to the values that are meaningful to the program
const mapping = [_]u8{
    0x00, // floor
    0x85, // spooky block, bottom left
    0x83, // spooky block, top left
    0x84, // spooky block, top right
    0x81, // wall (south face)
    0x86, // spooky block, bottom right
    0x80, // wall
    0x01, // floor with shadow
    0x87, // station, top left
    0x88, // station, top right
    0x89, // station, bottom left
    0x8A, // station, bottom right
    0x02, // station, shadow left
    0x03, // station, shadow right
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
