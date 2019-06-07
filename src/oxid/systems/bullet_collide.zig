const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const SimpleAnim = @import("../graphics.zig").SimpleAnim;
const Constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

const SystemData = struct {
    id: gbe.EntityId,
    bullet: *const c.Bullet,
    transform: *const c.Transform,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    var it = gs.eventIter(c.EventCollide, "self_id", self.id); while (it.next()) |event| {
        _ = p.Animation.spawn(gs, p.Animation.Params {
            .pos = self.transform.pos,
            .simple_anim = SimpleAnim.PlaSparks,
            .z_index = Constants.ZIndexSparks,
        }) catch undefined;
        if (!gbe.EntityId.isZero(event.other_id)) {
            _ = p.EventTakeDamage.spawn(gs, c.EventTakeDamage {
                .inflictor_player_controller_id = self.bullet.inflictor_player_controller_id,
                .self_id = event.other_id,
                .amount = self.bullet.damage,
            }) catch undefined;
        }
        return false;
    }
    return true;
}
