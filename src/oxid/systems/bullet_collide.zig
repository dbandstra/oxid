const gbe = @import("../../gbe.zig");
const GameSession = @import("../game.zig").GameSession;
const SimpleAnim = @import("../graphics.zig").SimpleAnim;
const Constants = @import("../constants.zig");
const C = @import("../components.zig");
const Prototypes = @import("../prototypes.zig");

const SystemData = struct {
    id: gbe.EntityId,
    bullet: *const C.Bullet,
    transform: *const C.Transform,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    var it = gs.eventIter(C.EventCollide, "self_id", self.id); while (it.next()) |event| {
        _ = Prototypes.Animation.spawn(gs, Prototypes.Animation.Params {
            .pos = self.transform.pos,
            .simple_anim = SimpleAnim.PlaSparks,
            .z_index = Constants.ZIndexSparks,
        }) catch undefined;
        if (!gbe.EntityId.isZero(event.other_id)) {
            _ = Prototypes.EventTakeDamage.spawn(gs, C.EventTakeDamage {
                .inflictor_player_controller_id = self.bullet.inflictor_player_controller_id,
                .self_id = event.other_id,
                .amount = self.bullet.damage,
            }) catch undefined;
        }
        return false;
    }
    return true;
}
