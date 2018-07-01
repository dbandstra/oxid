const assert = @import("std").debug.assert;

const Vec2 = @import("math.zig").Vec2;

pub fn boxes_overlap(apos: Vec2, adims: Vec2, bpos: Vec2, bdims: Vec2) bool {
  assert(adims.x > 0 and adims.y > 0);
  assert(bdims.x > 0 and bdims.y > 0);

  return
    apos.x + adims.x > bpos.x and
    bpos.x + bdims.x > apos.x and
    apos.y + adims.y > bpos.y and
    bpos.y + bdims.y > apos.y;
}

test "boxes_overlap" {
  const dims = Vec2{ .x = 16, .y = 16 };

  assert(!boxes_overlap(
    Vec2{ .x = 0, .y = 0 }, dims,
    Vec2{ .x = 16, .y = 0 }, dims,
  ));
  assert(boxes_overlap(
    Vec2{ .x = 0, .y = 0 }, dims,
    Vec2{ .x = 15, .y = 0 }, dims,
  ));
  assert(!boxes_overlap(
    Vec2{ .x = 0, .y = 0 }, dims,
    Vec2{ .x = -16, .y = 0 }, dims,
  ));
  assert(boxes_overlap(
    Vec2{ .x = 0, .y = 0 }, dims,
    Vec2{ .x = -15, .y = 0 }, dims,
  ));
}
