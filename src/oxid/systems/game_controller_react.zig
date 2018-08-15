const Gbe = @import("../../gbe.zig");
const GbeSystem = @import("../../gbe_system.zig");
const GameSession = @import("../game.zig").GameSession;
const Constants = @import("../constants.zig");
const C = @import("../components.zig");

const SystemData = struct{
  gc: *C.GameController,
};

pub const run = GbeSystem.build(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
  if (gs.gbe.iter(C.EventPlayerDied).next() != null) {
    self.gc.freeze_monsters_timer = Constants.MonsterFreezeTime;
  }
  var it = gs.gbe.iter(C.EventMonsterDied); while (it.next()) |object| {
    if (self.gc.monster_count > 0) {
      self.gc.monster_count -= 1;
      if (self.gc.monster_count == 4 and self.gc.enemy_speed_level < 1) {
        self.gc.enemy_speed_level = 1;
      }
      if (self.gc.monster_count == 3 and self.gc.enemy_speed_level < 2) {
        self.gc.enemy_speed_level = 2;
      }
      if (self.gc.monster_count == 2 and self.gc.enemy_speed_level < 3) {
        self.gc.enemy_speed_level = 3;
      }
      if (self.gc.monster_count == 1 and self.gc.enemy_speed_level < 4) {
        self.gc.enemy_speed_level = 4;
      }
    }
  }
  return true;
}
