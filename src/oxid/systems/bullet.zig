const GameSession = @import("../game.zig").GameSession;
const getLineOfFire = @import("../functions/get_line_of_fire.zig").getLineOfFire;
const c = @import("../components.zig");

pub fn run(gs: *GameSession) void {
    var it = gs.ecs.iter(struct {
        transform: *const c.Transform,
        phys: *const c.PhysObject,
        bullet: *c.Bullet,
    });
    while (it.next()) |self| {
        self.bullet.line_of_fire = getLineOfFire(
            self.transform.pos,
            self.phys.entity_bbox,
            self.phys.facing,
        );
    }
}
