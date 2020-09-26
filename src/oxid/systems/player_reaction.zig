const gbe = @import("gbe");
const game = @import("../game.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");
const audio = @import("../audio.zig");

pub fn run(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        player: *c.Player,
        voice_coin: *c.VoiceCoin,
        voice_power_up: *c.VoicePowerUp,
        voice_sampler: *c.VoiceSampler,
        inbox: gbe.Inbox(8, c.EventConferBonus, "recipient_id"),
    });
    while (it.next()) |self| {
        for (self.inbox.all()) |event| {
            switch (event.pickup_type) {
                .power_up => {
                    self.voice_power_up.params = .{};
                    self.player.attack_level = switch (self.player.attack_level) {
                        .one => .two,
                        else => .three,
                    };
                    self.player.last_pickup = .power_up;
                },
                .speed_up => {
                    self.voice_power_up.params = .{};
                    self.player.speed_level = switch (self.player.speed_level) {
                        .one => .two,
                        else => .three,
                    };
                    self.player.last_pickup = .speed_up;
                },
                .life_up => {
                    self.voice_sampler.sample = .extra_life;
                    _ = p.EventAwardLife.spawn(gs, .{
                        .player_controller_id = self.player.player_controller_id,
                    }) catch undefined;
                },
                .coin => {
                    self.voice_coin.params = .{
                        .freq_mul = 0.95 + 0.1 * gs.getRand().float(f32),
                    };
                },
            }
        }
    }
}
