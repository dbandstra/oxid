const std = @import("std");

const Math = @import("common/math.zig");
const GRIDSIZE_SUBPIXELS = @import("level.zig").GRIDSIZE_SUBPIXELS;
const Level = @import("level.zig").Level;

test "box_in_wall" {
    const level = Level(3, 3).init(blk: {
        const x = 0x00;
        const O = 0x80;

        break :blk []const u8{
            O,O,O,
            O,x,O,
            O,O,O,
        };
    });

    const s = GRIDSIZE_SUBPIXELS;

    // TODO - hardcode these instead of multiplying.
    // provide gridsize within the level object so we can specify
    // a custom one in the test.

    const bbox = Math.BoundingBox{
        .mins = Math.Vec2.init(0, 0),
        .maxs = Math.Vec2.init(s-1, s-1),
    };

    std.testing.expect(!level.boxInWall(Math.Vec2.init(1*s, 1*s), bbox, false));

    std.testing.expect(level.boxInWall(Math.Vec2.init(1*s-1, 1*s), bbox, false));
    std.testing.expect(level.boxInWall(Math.Vec2.init(1*s+1, 1*s), bbox, false));
    std.testing.expect(level.boxInWall(Math.Vec2.init(1*s, 1*s-1), bbox, false));
    std.testing.expect(level.boxInWall(Math.Vec2.init(1*s, 1*s+1), bbox, false));
}
