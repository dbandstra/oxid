const std = @import("std");
const gbe = @import("gbe");
const draw = @import("../../common/draw.zig");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

const SystemData = struct {
    bullet: *const c.Bullet,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    if (self.bullet.line_of_fire) |box| {
        _ = p.EventDrawBox.spawn(gs, c.EventDrawBox {
            .box = box,
            .color = draw.Black,
        }) catch undefined;
    }
    return true;
}
