const Math = @import("../../math.zig");
const Gbe = @import("../../gbe.zig");
const GbeSystem = @import("../../gbe_system.zig");
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
    spawnPlayer(gs, self.id);
  }
  return true;
}

fn spawnPlayer(gs: *GameSession, player_controller_id: Gbe.EntityId) void {
  _ = Prototypes.Player.spawn(gs, Prototypes.Player.Params{
    .player_controller_id = player_controller_id,
    .pos = Math.Vec2.init(
      9 * GRIDSIZE_SUBPIXELS + GRIDSIZE_SUBPIXELS / 2,
      5 * GRIDSIZE_SUBPIXELS,
    ),
  });
}
