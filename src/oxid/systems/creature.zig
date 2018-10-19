const Gbe = @import("../../gbe.zig");
const GbeSystem = @import("../../gbe_system.zig");
const GameSession = @import("../game.zig").GameSession;
const C = @import("../components.zig");
const GameUtil = @import("../util.zig");

const SystemData = struct.{
  creature: *C.Creature,
};

pub const run = GbeSystem.build(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
  _ = GameUtil.decrementTimer(&self.creature.invulnerability_timer);
  _ = GameUtil.decrementTimer(&self.creature.flinch_timer);
  return true;
}
