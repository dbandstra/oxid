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

pub fn run(gs: *GameSession) void {
    var it = gs.ecs.iter(SystemData);
    while (it.next()) |self| {
        monsterCollide(gs, self);
    }
}

fn monsterCollide(gs: *GameSession, self: SystemData) void {
    var hit_wall = false;
    var hit_creature = false;

    var it = gs.ecs.componentIter(c.EventCollide);
    while (it.next()) |event| {
        if (!gbe.EntityId.eql(event.self_id, self.id)) {
            continue;
        }

        if (gbe.EntityId.isZero(event.other_id)) {
            hit_wall = true;
            continue;
        }

        const other = gs.ecs.findById(event.other_id, struct {
            creature: *const c.Creature,
            phys: *const c.PhysObject,
            player: ?*const c.Player,
        }) orelse continue;

        if (event.propelled and !self.phys.illusory and !other.phys.illusory) {
            hit_creature = true;
        }

        // if it's a player creature, inflict damage on it
        if (other.player != null and self.monster.spawning_timer == 0) {
            _ = p.EventTakeDamage.spawn(gs, .{
                .inflictor_player_controller_id = null,
                .self_id = event.other_id,
                .amount = 1,
            }) catch undefined;
        }
    }

    if (hit_creature) {
        // reverse direction
        self.phys.facing = math.Direction.invert(self.phys.facing);
    }
}
