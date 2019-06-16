const std = @import("std");

const math = @import("../common/math.zig");
const levels = @import("levels.zig");

test "box_in_wall" {
    const level = levels.GenLevel(3, 3).init(blk: {
        const x = 0x00; // floor
        const O = 0x80; // wall

        break :blk [_]u8 {
            O, O, O,
            O, x, O,
            O, O, O,
        };
    });

    const s = levels.SUBPIXELS_PER_TILE;

    // TODO - hardcode these instead of multiplying.
    // provide gridsize within the level object so we can specify
    // a custom one in the test.

    const bbox = math.BoundingBox {
        .mins = math.Vec2.init(0, 0),
        .maxs = math.Vec2.init(s-1, s-1),
    };

    std.testing.expect(!level.boxInWall(math.Vec2.init(1*s, 1*s), bbox, false));

    std.testing.expect(level.boxInWall(math.Vec2.init(1*s-1, 1*s), bbox, false));
    std.testing.expect(level.boxInWall(math.Vec2.init(1*s+1, 1*s), bbox, false));
    std.testing.expect(level.boxInWall(math.Vec2.init(1*s, 1*s-1), bbox, false));
    std.testing.expect(level.boxInWall(math.Vec2.init(1*s, 1*s+1), bbox, false));
}
