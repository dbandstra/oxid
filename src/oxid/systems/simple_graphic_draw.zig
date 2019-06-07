const gbe = @import("gbe");
const draw = @import("../../common/draw.zig");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");
const p = @import("../prototypes.zig");
const util = @import("../util.zig");

const SystemData = struct{
    transform: *const c.Transform,
    phys: ?*const c.PhysObject,
    simple_graphic: *const c.SimpleGraphic,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    _ = p.EventDraw.spawn(gs, c.EventDraw{
        .pos = self.transform.pos,
        .graphic = self.simple_graphic.graphic,
        .transform =
            if (self.simple_graphic.directional)
                if (self.phys) |phys|
                    util.getDirTransform(phys.facing)
                else
                    draw.Transform.Identity
            else
                draw.Transform.Identity,
        .z_index = self.simple_graphic.z_index,
    }) catch undefined;
    return true;
}
