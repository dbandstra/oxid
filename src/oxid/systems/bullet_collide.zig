const Gbe = @import("../../gbe.zig");
const GbeSystem = @import("../../gbe_system.zig");
const GameSession = @import("../game.zig").GameSession;
const SimpleAnim = @import("../graphics.zig").SimpleAnim;
const Constants = @import("../constants.zig");
const C = @import("../components.zig");
const Prototypes = @import("../prototypes.zig");

const SystemData = struct {
  id: Gbe.EntityId,
  bullet: *C.Bullet,
  transform: *C.Transform,
};

pub const run = GbeSystem.build(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
  var it = gs.gbe.eventIter(C.EventCollide, "self_id", self.id); while (it.next()) |event| {
    _ = Prototypes.Animation.spawn(gs, Prototypes.Animation.Params{
      .pos = self.transform.pos,
      .simple_anim = SimpleAnim.PlaSparks,
      .z_index = Constants.ZIndexSparks,
    });
    if (!Gbe.EntityId.isZero(event.other_id)) {
      _ = Prototypes.EventTakeDamage.spawn(gs, C.EventTakeDamage{
        .inflictor_player_controller_id = self.bullet.inflictor_player_controller_id,
        .self_id = event.other_id,
        .amount = self.bullet.damage,
      });
    }
    return false;
  }
  return true;
}
