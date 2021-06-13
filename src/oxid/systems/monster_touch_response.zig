const gbe = @import("gbe");
const math = @import("../../common/math.zig");
const game = @import("../game.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

const SystemData = struct {
    id: gbe.EntityId,
    phys: *c.PhysObject,
    creature: *c.Creature,
    monster: *c.Monster,
    inbox: gbe.Inbox(16, c.EventCollide, "self_id"),
};

pub fn run(gs: *game.Session) void {
    var it = gs.ecs.iter(SystemData);
    while (it.next()) |self| {
        monsterCollide(gs, self);
    }
}

fn monsterCollide(gs: *game.Session, self: SystemData) void {
    var hit_creature = false;

    for (self.inbox.all()) |event| {
        if (gbe.EntityId.isZero(event.other_id))
            continue; // hit a wall

        const other = gs.ecs.findById(event.other_id, struct {
            creature: *const c.Creature,
            phys: *const c.PhysObject,
            player: ?*const c.Player,
        }) orelse continue;

        if (event.collision_type == .propelled and !self.phys.illusory and !other.phys.illusory)
            hit_creature = true;

        // only hurt players. if we touch another monster we'll just bounce off of it
        if (other.player == null)
            continue;

        // if it's a player creature, inflict damage on it.
        // the monster doesn't inflict damage in the spawning state, unless it's an overlap
        // collision event. that implies that the player, while freshly spawned (illusory blinking
        // state), stepped onto a spawning monster, and then the illusory state expired. if we
        // didn't kill the player here, the player and monster would be stuck jammed into each
        // other until the monster finished spawning as well.
        if (self.monster.spawning_timer == 0 or event.collision_type == .overlap) {
            if (self.monster.spawning_timer > 0) {
                // spawn "early" if killing a player, so it looks less weird
                self.monster.spawning_timer = 0;
                self.creature.hit_points = self.monster.full_hit_points;
            }
            p.spawnEventTakeDamage(gs, .{
                .inflictor_player_controller_id = null,
                .self_id = event.other_id,
                .amount = 1,
            });
        }
    }

    if (hit_creature) {
        // reverse direction
        self.phys.facing = math.invertDirection(self.phys.facing);
    }
}
