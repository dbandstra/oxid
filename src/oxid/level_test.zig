const assert = @import("std").debug.assert;

const Vec2 = @import("math.zig").Vec2;
const GRIDSIZE_SUBPIXELS = @import("game_level.zig").GRIDSIZE_SUBPIXELS;
const Level = @import("game_level.zig").Level;

test "box_in_wall" {
  const level = Level(3, 3).init(blk: {
    const _ = 0x00;
    const O = 0x80;

    break :blk []const u8{
      O,O,O,
      O,_,O,
      O,O,O,
    };
  });

  const s = GRIDSIZE_SUBPIXELS;

  // TODO - hardcode these instead of multiplying.
  // provide gridsize within the level object so we can specify
  // a custom one in the test.

  const dims = Vec2.init(1*s, 1*s);

  assert(!level.boxInWall(Vec2.init(1*s, 1*s,), dims));

  assert(level.boxInWall(Vec2.init(1*s-1, 1*s,), dims));
  assert(level.boxInWall(Vec2.init(1*s+1, 1*s,), dims));
  assert(level.boxInWall(Vec2.init(1*s, 1*s-1,), dims));
  assert(level.boxInWall(Vec2.init(1*s, 1*s+1,), dims));
}
