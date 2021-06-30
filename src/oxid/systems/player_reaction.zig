const gbe = @import("gbe");
const game = @import("../game.zig");
const constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

pub fn run(gs: *game.Session) void {
    restoreOxygen(gs);
    conferBonus(gs);
}

fn restoreOxygen(gs: *game.Session) void {
    if (gs.ecs.componentIter(c.EventRestoreOxygen).next() == null)
        return;

    var it = gs.ecs.componentIter(c.Player);
    while (it.next()) |player| {
        player.oxygen += constants.oxygen_per_wave;
        if (player.oxygen > constants.max_oxygen)
            player.oxygen = constants.max_oxygen;
        player.oxygen_timer = constants.ticks_per_oxygen_spent;
    }
}
fn conferBonus(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        player: *c.Player,
        inbox: gbe.Inbox(8, c.EventConferBonus, "recipient_id"),
    });
    while (it.next()) |self| {
        for (self.inbox.all()) |event| {
            switch (event.pickup_type) {
                .power_up => {
                    p.playSound(gs, .power_up);
                    self.player.attack_level = switch (self.player.attack_level) {
                        .one => .two,
                        else => .three,
                    };
                    self.player.last_pickup = .power_up;
                },
                .speed_up => {
                    p.playSound(gs, .power_up);
                    self.player.speed_level = switch (self.player.speed_level) {
                        .one => .two,
                        else => .three,
                    };
                    self.player.last_pickup = .speed_up;
                },
                .life_up => {
                    p.playSound(gs, .{ .sample = .extra_life });
                    p.spawnEventAwardLife(gs, .{
                        .player_controller_id = self.player.player_controller_id,
                    });
                },
                .coin => {
                    p.playSound(gs, .{
                        .coin = .{
                            .freq_mul = 0.95 + 0.1 * gs.prng.random.float(f32),
                        },
                    });
                    self.player.oxygen += constants.oxygen_per_coin;
                    if (self.player.oxygen > constants.max_oxygen)
                        self.player.oxygen = constants.max_oxygen;
                    self.player.oxygen_timer = constants.ticks_per_oxygen_spent;
                },
            }
        }
    }
}
