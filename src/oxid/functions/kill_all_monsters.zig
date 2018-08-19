const GameSession = @import("../game.zig").GameSession;
const C = @import("../components.zig");

// FIXME - run this through the input system properly instead of calling it
// directly from the main function

// this is a cheat
pub fn killAllMonsters(gs: *GameSession) void {
  var killed_any = false;

  var it = gs.gbe.iter(C.Monster); while (it.next()) |object| {
    if (!object.data.persistent) {
      gs.gbe.markEntityForRemoval(object.entity_id);
      killed_any = true;
    }
  }
  gs.gbe.applyRemovals();

  if (killed_any) {
    if (gs.gbe.iter(C.GameController).next()) |object| {
      object.data.next_wave_timer = 1;
    }
  }
}
