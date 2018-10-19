const GbeSystem = @import("../../gbe_system.zig");
const GameSession = @import("../game.zig").GameSession;
const C = @import("../components.zig");
const Prototypes = @import("../prototypes.zig");

const SystemData = struct.{
  mc: *C.MainController,
};

pub const run = GbeSystem.build(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
  var it = gs.iter(C.EventPostScore); while (it.next()) |object| {
    const score = object.data.score;
    if (score > self.mc.high_score) {
      self.mc.high_score = score;
      self.mc.new_high_score = true;
      _ = Prototypes.EventSaveHighScore.spawn(gs, C.EventSaveHighScore.{
        .high_score = score,
      });
    } else {
      self.mc.new_high_score = false;
    }
  }
  return true;
}
