const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");
const p = @import("../prototypes.zig");
const audio = @import("../audio.zig");

pub fn run(gs: *GameSession) void {
    var it = gs.ecs.iter(struct {
        player: *c.Player,
        inbox: gbe.Inbox(8, c.EventConferBonus, "recipient_id"),
    });
    while (it.next()) |self| {
        for (self.inbox.all()) |event| {
            switch (event.pickup_type) {
                .power_up => {
                    _ = p.VoiceSampler.spawn(gs, .power_up) catch undefined;
                    self.player.attack_level = switch (self.player.attack_level) {
                        .one => .two,
                        else => .three,
                    };
                    self.player.last_pickup = .power_up;
                },
                .speed_up => {
                    _ = p.VoiceSampler.spawn(gs, .power_up) catch undefined;
                    self.player.speed_level = switch (self.player.speed_level) {
                        .one => .two,
                        else => .three,
                    };
                    self.player.last_pickup = .speed_up;
                },
                .life_up => {
                    _ = p.VoiceSampler.spawn(gs, .extra_life) catch undefined;
                    _ = p.EventAwardLife.spawn(gs, .{
                        .player_controller_id = self.player.player_controller_id,
                    }) catch undefined;
                },
                .coin => {
                    _ = p.VoiceCoin.spawn(gs, .{
                        .freq_mul = 0.95 + 0.1 * gs.getRand().float(f32),
                    }) catch undefined;
                },
            }
        }
    }
}
