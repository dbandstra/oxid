const std = @import("std");
const gbe = @import("gbe");
const draw = @import("../../common/draw.zig");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

const SystemData = struct {
    player: *const c.Player,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) gbe.ThinkResult {
    if (self.player.line_of_fire) |box| {
        _ = p.EventDrawBox.spawn(gs, .{
            .box = box,
            .color = draw.black,
        }) catch undefined;
    }
    return .Remain;
}
