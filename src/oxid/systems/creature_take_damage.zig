const gbe = @import("gbe");
const game = @import("../game.zig");
const constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

pub fn run(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        id: gbe.EntityId,
        creature: *c.Creature,
        transform: *const c.Transform,
        monster: ?*const c.Monster,
        player: ?*c.Player,
        inbox: gbe.Inbox(8, c.EventTakeDamage, "self_id"),
    });
    while (it.next()) |self| {
        if (self.creature.invulnerability_timer > 0) continue;
        if (self.creature.hit_points <= 0) continue;

        const total_damage = blk: {
            var n: u32 = 0;
            for (self.inbox.all()) |event|
                n += event.amount;
            break :blk n;
        };

        if (total_damage <= 0) continue;

        if (self.creature.hit_points > total_damage) {
            // hurt but not killed
            self.creature.hit_points -= total_damage;
            self.creature.flinch_timer = constants.duration60(4);
            continue;
        }

        // killed
        self.creature.hit_points = 0;

        if (self.player) |self_player| {
            // player died
            p.playSound(gs, .{ .sample = .player_death });

            self_player.dying_timer = constants.player_death_anim_time;

            p.spawnEventPlayerDied(gs, .{
                .player_controller_id = self_player.player_controller_id,
            });

            if (self_player.last_pickup) |pickup_type| {
                _ = p.spawnPickup(gs, .{
                    .pos = self.transform.pos,
                    .pickup_type = pickup_type,
                });
            }

            // players don't explode immediately like monsters. they play a
            // death animation and then are replaced by a corpse entity
            continue;
        }

        // something other than a player died
        if (self.monster) |self_monster| {
            p.spawnEventMonsterDied(gs, .{});

            // in the case that multiple players shot this monster at the same
            // time, pick one of them at random to award the kill to
            if (self.inbox.one().inflictor_player_controller_id) |player_controller_id| {
                p.spawnEventAwardPoints(gs, .{
                    .player_controller_id = player_controller_id,
                    .points = constants.getMonsterValues(self_monster.monster_type).kill_points,
                });
            }

            if (self_monster.has_coin) {
                _ = p.spawnPickup(gs, .{
                    .pos = self.transform.pos,
                    .pickup_type = .coin,
                });
            }
        }

        p.playSound(gs, .explosion);
        _ = p.spawnExplosion(gs, .{
            .pos = self.transform.pos,
        });

        gs.ecs.markForRemoval(self.id);
    }
}
