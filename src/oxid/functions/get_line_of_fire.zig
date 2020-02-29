const std = @import("std");
const warn = @import("../../warn.zig").warn;
const math = @import("../../common/math.zig");
const levels = @import("../levels.zig");

pub fn getLineOfFire(
    bullet_pos: math.Vec2,
    bullet_bbox: math.BoundingBox,
    facing: math.Direction,
) ?math.BoundingBox {
    // create a box that represents the path of a bullet fired by the player in
    // the current frame, ignoring monsters.
    // certain monster behaviours will use this in order to try to get out of the
    // way
    var box = math.BoundingBox.move(bullet_bbox, bullet_pos);

    var sanity: usize = 0;
    while (sanity < 10000) : (sanity += 1) {
        switch (facing) {
            .n => box.mins.y -= 1,
            .e => box.maxs.x += 1,
            .s => box.maxs.y += 1,
            .w => box.mins.x -= 1,
        }

        if (levels.level1.absBoxInWall(box)) {
            switch (facing) {
                .n => box.mins.y += 1,
                .e => box.maxs.x -= 1,
                .s => box.maxs.y -= 1,
                .w => box.mins.x += 1,
            }

            return box;
        }
    }

    warn("getLineOfFire: infinite loop?\n", .{});
    return null;
}
