const std = @import("std");
const math = @import("../common/math.zig");
const levels = @import("levels.zig");

const wall: levels.MapTile = .{
    .graphic = .wall,
    .terrain_type = .wall,
    .foreground = false,
};

const floor: levels.MapTile = .{
    .graphic = .floor,
    .terrain_type = .floor,
    .foreground = false,
};

test "box_in_wall" {
    var tiles = [1]levels.MapTile{wall} ** (levels.width * levels.height); // initialize to all walls
    tiles[1 * levels.width + 1] = floor; // set tile at x=1, y=1 to floor
    const level: levels.Level = .{ .tiles = tiles };

    const s = levels.subpixels_per_tile;

    const bbox: math.Box = .{
        .mins = math.vec2(0, 0),
        .maxs = math.vec2(s - 1, s - 1),
    };

    try std.testing.expect(!levels.boxInWall(level, math.vec2(1 * s, 1 * s), bbox));

    try std.testing.expect(levels.boxInWall(level, math.vec2(1 * s - 1, 1 * s), bbox));
    try std.testing.expect(levels.boxInWall(level, math.vec2(1 * s + 1, 1 * s), bbox));
    try std.testing.expect(levels.boxInWall(level, math.vec2(1 * s, 1 * s - 1), bbox));
    try std.testing.expect(levels.boxInWall(level, math.vec2(1 * s, 1 * s + 1), bbox));
}
