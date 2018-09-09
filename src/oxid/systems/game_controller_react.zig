const Gbe = @import("../../gbe.zig");
const GbeSystem = @import("../../gbe_system.zig");
const Audio = @import("../audio.zig");
const GameSession = @import("../game.zig").GameSession;
const Constants = @import("../constants.zig");
const C = @import("../components.zig");
const Prototypes = @import("../prototypes.zig");

const SystemData = struct{
  gc: *C.GameController,
};

pub const run = GbeSystem.build(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
  if (gs.findFirst(C.EventPlayerDied) != null) {
    self.gc.freeze_monsters_timer = Constants.MonsterFreezeTime;
  }
  var it = gs.iter(C.EventPlayerOutOfLives); while (it.next()) |object| {
    self.gc.game_over = true;
    if (gs.find(object.data.player_controller_id, C.PlayerController)) |pc| {
      _ = Prototypes.EventPostScore.spawn(gs, C.EventPostScore{
        .score = pc.score,
      });
    }
  }
  var it2 = gs.iter(C.EventMonsterDied); while (it2.next()) |_| {
    if (self.gc.monster_count > 0) {
      self.gc.monster_count -= 1;
      if (self.gc.monster_count == 4 and self.gc.enemy_speed_level < 1) {
        self.gc.enemy_speed_timer = 1;
      }
      if (self.gc.monster_count == 3 and self.gc.enemy_speed_level < 2) {
        self.gc.enemy_speed_timer = 1;
      }
      if (self.gc.monster_count == 2 and self.gc.enemy_speed_level < 3) {
        self.gc.enemy_speed_timer = 1;
      }
      if (self.gc.monster_count == 1 and self.gc.enemy_speed_level < 4) {
        self.gc.enemy_speed_timer = 1;
      }
    }
  }
  return true;
}
