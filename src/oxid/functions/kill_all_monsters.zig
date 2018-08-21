const GameSession = @import("../game.zig").GameSession;
const C = @import("../components.zig");

// FIXME - run this through the input system properly instead of calling it
// directly from the main function

// this is a cheat
pub fn killAllMonsters(gs: *GameSession) void {
  var it = gs.gbe.iter(C.Monster); while (it.next()) |object| {
    if (!object.data.persistent) {
      gs.gbe.markEntityForRemoval(object.entity_id);
    }
  }
  gs.gbe.applyRemovals();

  if (gs.gbe.iter(C.GameController).next()) |object| {
    object.data.next_wave_timer = 1;
  }
}
