const std = @import("std");
const gbe = @import("gbe");
const draw = @import("../../common/draw.zig");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

const SystemData = struct{
    phys: *const c.PhysObject,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) gbe.ThinkResult {
    const int = self.phys.internal;
    _ = p.EventDrawBox.spawn(gs, c.EventDrawBox {
        .box = int.move_bbox,
        .color = draw.Color {
            .r = @intCast(u8, 64 + ((int.group_index * 41) % 192)),
            .g = @intCast(u8, 64 + ((int.group_index * 901) % 192)),
            .b = @intCast(u8, 64 + ((int.group_index * 10031) % 192)),
        },
    }) catch undefined;
    return .Remain;
}
