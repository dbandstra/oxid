const std = @import("std");
const Math = @import("../common/math.zig");
const LEVEL = @import("../level.zig").LEVEL;

pub fn getLineOfFire(
    bullet_pos: Math.Vec2,
    bullet_bbox: Math.BoundingBox,
    facing: Math.Direction,
) ?Math.BoundingBox {
    // create a box that represents the path of a bullet fired by the player in
    // the current frame, ignoring monsters.
    // certain monster behaviours will use this in order to try to get out of the
    // way
    var box = Math.BoundingBox.move(bullet_bbox, bullet_pos);

    var sanity: usize = 0;
    while (sanity < 10000) : (sanity += 1) {
        switch (facing) {
            Math.Direction.N => box.mins.y -= 1,
            Math.Direction.E => box.maxs.x += 1,
            Math.Direction.S => box.maxs.y += 1,
            Math.Direction.W => box.mins.x -= 1,
        }

        if (LEVEL.absBoxInWall(box, true)) {
            switch (facing) {
                Math.Direction.N => box.mins.y += 1,
                Math.Direction.E => box.maxs.x -= 1,
                Math.Direction.S => box.maxs.y -= 1,
                Math.Direction.W => box.mins.x += 1,
            }

            return box;
        }
    }

    std.debug.warn("getLineOfFire: infinite loop?\n");
    return null;
}
