const gbe = @import("gbe");
const math = @import("../../common/math.zig");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

const SystemData = struct {
    id: gbe.EntityId,
    phys: *c.PhysObject,
    monster: *const c.Monster,
};

pub const run = gbe.buildSystem(GameSession, SystemData, monsterCollide);

fn monsterCollide(gs: *GameSession, self: SystemData) gbe.ThinkResult {
    var hit_wall = false;
    var hit_creature = false;

    var it = gs.eventIter(c.EventCollide, "self_id", self.id); while (it.next()) |event| {
        if (gbe.EntityId.isZero(event.other_id)) {
            hit_wall = true;
        } else {
            const other_creature = gs.find(event.other_id, c.Creature) orelse continue;
            const other_phys = gs.find(event.other_id, c.PhysObject) orelse continue;

            if (event.propelled and !self.phys.illusory and !other_phys.illusory) {
                hit_creature = true;
            }
            if (gs.find(event.other_id, c.Player) != null) {
                // if it's a player creature, inflict damage on it
                if (self.monster.spawning_timer == 0) {
                    _ = p.EventTakeDamage.spawn(gs, c.EventTakeDamage {
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
        self.phys.facing = math.Direction.invert(self.phys.facing);
    }
    return .Remain;
}
