const Gbe = @import("../../gbe.zig");
const GbeSystem = @import("../../gbe_system.zig");
const GameSession = @import("../game.zig").GameSession;
const C = @import("../components.zig");
const Prototypes = @import("../prototypes.zig");

const SystemData = struct.{
  id: Gbe.EntityId,
  pickup: *const C.Pickup,
};

pub const run = GbeSystem.build(GameSession, SystemData, collide);

fn collide(gs: *GameSession, self: SystemData) bool {
  var it = gs.eventIter(C.EventCollide, "self_id", self.id); while (it.next()) |event| {
    const other_player = gs.find(event.other_id, C.Player) orelse continue;
    _ = Prototypes.EventConferBonus.spawn(gs, C.EventConferBonus.{
      .recipient_id = event.other_id,
      .pickup_type = self.pickup.pickup_type,
    });
    _ = Prototypes.EventAwardPoints.spawn(gs, C.EventAwardPoints.{
      .player_controller_id = other_player.player_controller_id,
      .points = self.pickup.get_points,
    });
    return false;
  }
  return true;
}
