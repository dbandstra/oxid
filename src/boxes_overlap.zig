const assert = @import("std").debug.assert;
const Math = @import("math.zig");

pub fn absBoxesOverlap(a: Math.BoundingBox, b: Math.BoundingBox) bool {
  assert(a.mins.x < a.maxs.x and a.mins.y < a.maxs.y);
  assert(b.mins.x < b.maxs.x and b.mins.y < b.maxs.y);

  return
    a.maxs.x >= b.mins.x and
    b.maxs.x >= a.mins.x and
    a.maxs.y >= b.mins.y and
    b.maxs.y >= a.mins.y;
}

pub fn boxesOverlap(
  a_pos: Math.Vec2, a_bbox: Math.BoundingBox,
  b_pos: Math.Vec2, b_bbox: Math.BoundingBox,
) bool {
  return absBoxesOverlap(
    Math.BoundingBox.move(a_bbox, a_pos),
    Math.BoundingBox.move(b_bbox, b_pos),
  );
}

test "boxesOverlap" {
  const bbox = Math.BoundingBox.{
    .mins = Math.Vec2.init(0, 0),
    .maxs = Math.Vec2.init(15, 15),
  };

  assert(!boxesOverlap(
    Math.Vec2.init(0, 0), bbox,
    Math.Vec2.init(16, 0), bbox,
  ));
  assert(boxesOverlap(
    Math.Vec2.init(0, 0), bbox,
    Math.Vec2.init(15, 0), bbox,
  ));
  assert(!boxesOverlap(
    Math.Vec2.init(0, 0), bbox,
    Math.Vec2.init(-16, 0), bbox,
  ));
  assert(boxesOverlap(
    Math.Vec2.init(0, 0), bbox,
    Math.Vec2.init(-15, 0), bbox,
  ));
}
