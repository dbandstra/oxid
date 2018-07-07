const assert = @import("std").debug.assert;
const Math = @import("math.zig");

pub fn abs_boxes_overlap(a: Math.BoundingBox, b: Math.BoundingBox) bool {
  assert(a.mins.x < a.maxs.x and a.mins.y < a.maxs.y);
  assert(b.mins.x < b.maxs.x and b.mins.y < b.maxs.y);

  return
    a.maxs.x >= b.mins.x and
    b.maxs.x >= a.mins.x and
    a.maxs.y >= b.mins.y and
    b.maxs.y >= a.mins.y;
}

pub fn boxes_overlap(
  a_pos: Math.Vec2, a_bbox: Math.BoundingBox,
  b_pos: Math.Vec2, b_bbox: Math.BoundingBox,
) bool {
  return abs_boxes_overlap(
    Math.BoundingBox.move(a_bbox, a_pos),
    Math.BoundingBox.move(b_bbox, b_pos),
  );
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
