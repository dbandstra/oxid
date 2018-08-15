const GameSession = @import("../game.zig").GameSession;
const C = @import("../components.zig");

// FIXME - run this through the input system properly instead of calling it
// directly from the main function

// this is a cheat
pub fn killAllMonsters(gs: *GameSession) void {
  var num_monsters: usize = 0;
  var it = gs.gbe.iter(C.Monster); while (it.next()) |object| {
    num_monsters += 1;
  }

  if (num_monsters > 0) {
    it = gs.gbe.iter(C.Monster); while (it.next()) |object| {
      gs.gbe.markEntityForRemoval(object.entity_id);
    }
    gs.gbe.applyRemovals();
  }

  if (gs.gbe.iter(C.GameController).next()) |object| {
    object.data.next_wave_timer = 1;
  }
}
