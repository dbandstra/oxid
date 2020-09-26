const std = @import("std");
const math = @import("../common/math.zig");
const levels = @import("levels.zig");

test "box_in_wall" {
    var data = [1]u8{0x80} ** (levels.width * levels.height); // initialize to all walls
    data[1 * levels.width + 1] = 0x00; // set tile at x=1, y=1 to floor
    const level: levels.Level = .{ .data = data };

    const s = levels.subpixels_per_tile;

    const bbox: math.Box = .{
        .mins = math.vec2(0, 0),
        .maxs = math.vec2(s - 1, s - 1),
    };

    std.testing.expect(!levels.boxInWall(level, math.vec2(1 * s, 1 * s), bbox));

    std.testing.expect(levels.boxInWall(level, math.vec2(1 * s - 1, 1 * s), bbox));
    std.testing.expect(levels.boxInWall(level, math.vec2(1 * s + 1, 1 * s), bbox));
    std.testing.expect(levels.boxInWall(level, math.vec2(1 * s, 1 * s - 1), bbox));
    std.testing.expect(levels.boxInWall(level, math.vec2(1 * s, 1 * s + 1), bbox));
}
