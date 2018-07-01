const assert = @import("std").debug.assert;

const Vec2 = @import("math.zig").Vec2;

pub fn boxes_overlap(
  apos: Vec2, amins: Vec2, amaxs: Vec2,
  bpos: Vec2, bmins: Vec2, bmaxs: Vec2,
) bool {
  assert(amins.x < amaxs.x and amins.y < amaxs.y);
  assert(bmins.x < bmaxs.x and bmins.y < bmaxs.y);

  return
    apos.x + amaxs.x >= bpos.x + bmins.x and
    bpos.x + bmaxs.x >= apos.x + amins.x and
    apos.y + amaxs.y >= bpos.y + bmins.y and
    bpos.y + bmaxs.y >= apos.y + amins.y;
}

test "boxes_overlap" {
  const dims = Vec2.init(16, 16);

  assert(!boxes_overlap(
    Vec2.init(0, 0), dims,
    Vec2.init(16, 0), dims,
  ));
  assert(boxes_overlap(
    Vec2.init(0, 0), dims,
    Vec2.init(15, 0), dims,
  ));
  assert(!boxes_overlap(
    Vec2.init(0, 0), dims,
    Vec2.init(-16, 0), dims,
  ));
  assert(boxes_overlap(
    Vec2.init(0, 0), dims,
    Vec2.init(-15, 0), dims,
  ));
}
