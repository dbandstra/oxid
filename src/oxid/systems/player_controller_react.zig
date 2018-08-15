const Gbe = @import("../../gbe.zig");
const GbeSystem = @import("../../gbe_system.zig");
const GameSession = @import("../game.zig").GameSession;
const Constants = @import("../constants.zig");
const C = @import("../components.zig");

const SystemData = struct{
  id: Gbe.EntityId,
  pc: *C.PlayerController,
};

pub const run = GbeSystem.build(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
  var it = gs.gbe.eventIter(C.EventPlayerDied, "player_controller_id", self.id); while (it.next()) |_| {
    if (self.pc.lives > 0) {
      self.pc.lives -= 1;
      if (self.pc.lives > 0) {
        self.pc.respawn_timer = Constants.PlayerRespawnTime;
      }
    }
  }
  var it2 = gs.gbe.eventIter(C.EventAwardPoints, "player_controller_id", self.id); while (it2.next()) |event| {
    self.pc.score += event.points;
  }
  var it3 = gs.gbe.eventIter(C.EventAwardLife, "player_controller_id", self.id); while (it3.next()) |event| {
    self.pc.lives += 1;
  }
  return true;
}
