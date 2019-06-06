const gbe = @import("../../gbe.zig");
const GameSession = @import("../game.zig").GameSession;
const getLineOfFire = @import("../functions/get_line_of_fire.zig").getLineOfFire;
const C = @import("../components.zig");

const SystemData = struct {
    transform: *const C.Transform,
    phys: *const C.PhysObject,
    bullet: *C.Bullet,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    self.bullet.line_of_fire = getLineOfFire(self.transform.pos, self.phys.entity_bbox, self.phys.facing);
    return true;
}
