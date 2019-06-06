const std = @import("std");
const Draw = @import("../common/draw.zig");
const gbe = @import("../common/gbe.zig");
const GameSession = @import("../game.zig").GameSession;
const Constants = @import("../constants.zig");
const C = @import("../components.zig");
const Prototypes = @import("../prototypes.zig");
const GameUtil = @import("../util.zig");
const Graphic = @import("../graphics.zig").Graphic;
const getSimpleAnim = @import("../graphics.zig").getSimpleAnim;

const SystemData = struct{
    bullet: *const C.Bullet,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    if (self.bullet.line_of_fire) |box| {
        _ = Prototypes.EventDrawBox.spawn(gs, C.EventDrawBox{
            .box = box,
            .color = Draw.Color{
                .r = 0,
                .g = 0,
                .b = 0,
                .a = 255,
            },
        }) catch undefined;
    }
    return true;
}
