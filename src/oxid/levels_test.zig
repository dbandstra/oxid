const std = @import("std");

const math = @import("../common/math.zig");
const levels = @import("levels.zig");

test "box_in_wall" {
    const level = levels.Level.init(blk: {
        // initialize to all walls
        var map = [1]u8{0x80} ** (levels.width * levels.height);

        // set tile at x=1, y=1 to floor
        map[1 * levels.width + 1] = 0x00;

        break :blk map;
    });

    const s = levels.subpixels_per_tile;

    const bbox: math.BoundingBox = .{
        .mins = math.Vec2.init(0, 0),
        .maxs = math.Vec2.init(s - 1, s - 1),
    };

    std.testing.expect(!level.boxInWall(math.Vec2.init(1 * s, 1 * s), bbox));

    std.testing.expect(level.boxInWall(math.Vec2.init(1 * s - 1, 1 * s), bbox));
    std.testing.expect(level.boxInWall(math.Vec2.init(1 * s + 1, 1 * s), bbox));
    std.testing.expect(level.boxInWall(math.Vec2.init(1 * s, 1 * s - 1), bbox));
    std.testing.expect(level.boxInWall(math.Vec2.init(1 * s, 1 * s + 1), bbox));
}
