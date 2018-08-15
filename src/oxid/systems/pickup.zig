const Gbe = @import("../../gbe.zig");
const GbeSystem = @import("../../gbe_system.zig");
const GameSession = @import("../game.zig").GameSession;
const C = @import("../components.zig");
const GameUtil = @import("../util.zig");

const SystemData = struct{
  pickup: *C.Pickup,
};

pub const run = GbeSystem.build(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
  if (GameUtil.decrementTimer(&self.pickup.timer)) {
    return false;
  }
  return true;
}
