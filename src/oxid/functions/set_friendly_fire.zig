const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");

pub const Context = struct {
    friendly_fire: bool,
};

const SystemData = struct {
    bullet: *const c.Bullet,
    phys: *c.PhysObject,
    context: Context,
};

pub const run = gbe.buildSystem(GameSession, SystemData, setFriendlyFireFunc);

fn setFriendlyFireFunc(gs: *GameSession, self: SystemData) gbe.ThinkResult {
    if (self.bullet.bullet_type == .PlayerBullet) {
        if (self.context.friendly_fire) {
            self.phys.ignore_flags &= ~c.PhysObject.FLAG_PLAYER;
        } else {
            self.phys.ignore_flags |= c.PhysObject.FLAG_PLAYER;
        }
    }
    return .Remain;
}
