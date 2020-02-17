const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");
const p = @import("../prototypes.zig");
const audio = @import("../audio.zig");

pub fn run(gs: *GameSession) void {
    var it = gs.entityIter(struct {
        id: gbe.EntityId,
        creature: *const c.Creature,
        phys: *const c.PhysObject,
        player: *c.Player,
        transform: *const c.Transform,
        inbox_confer_bonus: gbe.Inbox(c.EventConferBonus, "recipient_id"),
    });

    while (it.next()) |self| {
        const event = self.inbox_confer_bonus.head orelse continue;

        switch (event.pickup_type) {
            .PowerUp => {
                p.playSample(gs, .PowerUp);
                self.player.attack_level = switch (self.player.attack_level) {
                    .One => .Two,
                    else => .Three,
                };
                self.player.last_pickup = .PowerUp;
            },
            .SpeedUp => {
                p.playSample(gs, .PowerUp);
                self.player.speed_level = switch (self.player.speed_level) {
                    .One => .Two,
                    else => .Three,
                };
                self.player.last_pickup = .SpeedUp;
            },
            .LifeUp => {
                p.playSample(gs, .ExtraLife);
                _ = p.EventAwardLife.spawn(gs, .{
                    .player_controller_id = self.player.player_controller_id,
                }) catch undefined;
            },
            .Coin => {
                p.playSynth(gs, "Coin", audio.CoinVoice.NoteParams {
                    .freq_mul = 0.95 + 0.1 * gs.getRand().float(f32),
                });
            },
        }
    }
}
