const Math = @import("../common/math.zig");
const Gbe = @import("../common/gbe.zig");
const GbeSystem = @import("../common/gbe_system.zig");
const GameSession = @import("../game.zig").GameSession;
const GRIDSIZE_SUBPIXELS = @import("../level.zig").GRIDSIZE_SUBPIXELS;
const C = @import("../components.zig");
const Prototypes = @import("../prototypes.zig");
const GameUtil = @import("../util.zig");

const SystemData = struct{
  id: Gbe.EntityId,
  pc: *C.PlayerController,
};

pub const run = GbeSystem.build(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
  if (GameUtil.decrementTimer(&self.pc.respawn_timer)) {
    spawnPlayer(gs, self);
  }
  return true;
}

fn spawnPlayer(gs: *GameSession, self: SystemData) void {
  if (Prototypes.Player.spawn(gs, Prototypes.Player.Params{
    .player_controller_id = self.id,
    .pos = Math.Vec2.init(
      9 * GRIDSIZE_SUBPIXELS + GRIDSIZE_SUBPIXELS / 2,
      5 * GRIDSIZE_SUBPIXELS,
    ),
  })) |player_id| {
    self.pc.player_id = player_id;
  } else |_| {}
}
