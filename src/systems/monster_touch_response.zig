const Math = @import("../common/math.zig");
const gbe = @import("../common/gbe.zig");
const GameSession = @import("../game.zig").GameSession;
const C = @import("../components.zig");
const Prototypes = @import("../prototypes.zig");

const SystemData = struct{
  id: gbe.EntityId,
  phys: *C.PhysObject,
  monster: *const C.Monster,
};

pub const run = gbe.buildSystem(GameSession, SystemData, monsterCollide);

fn monsterCollide(gs: *GameSession, self: SystemData) bool {
  var hit_wall = false;
  var hit_creature = false;

  var it = gs.eventIter(C.EventCollide, "self_id", self.id); while (it.next()) |event| {
    if (gbe.EntityId.isZero(event.other_id)) {
      hit_wall = true;
    } else {
      const other_creature = gs.find(event.other_id, C.Creature) orelse continue;
      const other_phys = gs.find(event.other_id, C.PhysObject) orelse continue;

      if (event.propelled and !self.phys.illusory and !other_phys.illusory) {
        hit_creature = true;
      }
      if (gs.find(event.other_id, C.Player) != null) {
        // if it's a player creature, inflict damage on it
        if (self.monster.spawning_timer == 0) {
          _ = Prototypes.EventTakeDamage.spawn(gs, C.EventTakeDamage{
            .inflictor_player_controller_id = null,
            .self_id = event.other_id,
            .amount = 1,
          }) catch undefined;
        }
      }
    }
  }
  if (hit_creature) {
    // reverse direction
    self.phys.facing = Math.Direction.invert(self.phys.facing);
  }
  return true;
}
