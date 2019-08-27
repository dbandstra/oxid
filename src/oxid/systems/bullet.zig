const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const getLineOfFire = @import("../functions/get_line_of_fire.zig").getLineOfFire;
const c = @import("../components.zig");

const SystemData = struct {
    transform: *const c.Transform,
    phys: *const c.PhysObject,
    bullet: *c.Bullet,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) gbe.ThinkResult {
    self.bullet.line_of_fire = getLineOfFire(self.transform.pos, self.phys.entity_bbox, self.phys.facing);
    return .Remain;
}
