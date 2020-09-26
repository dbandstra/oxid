const game = @import("../game.zig");
const c = @import("../components.zig");

pub fn setFriendlyFire(gs: *game.Session, friendly_fire: bool) void {
    var it = gs.ecs.iter(struct {
        bullet: *const c.Bullet,
        phys: *c.PhysObject,
    });
    while (it.next()) |self| {
        if (self.bullet.bullet_type == .player_bullet) {
            if (friendly_fire) {
                self.phys.ignore_flags &= ~c.PhysObject.FLAG_PLAYER;
            } else {
                self.phys.ignore_flags |= c.PhysObject.FLAG_PLAYER;
            }
        }
    }
}
