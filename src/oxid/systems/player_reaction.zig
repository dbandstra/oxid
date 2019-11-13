const gbe = @import("gbe");
const ConstantTypes = @import("../constant_types.zig");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");
const p = @import("../prototypes.zig");
const audio = @import("../audio.zig");

const SystemData = struct {
    id: gbe.EntityId,
    creature: *const c.Creature,
    phys: *const c.PhysObject,
    player: *c.Player,
    transform: *const c.Transform,
};

pub const run = gbe.buildSystem(GameSession, SystemData, playerReact);

fn playerReact(gs: *GameSession, self: SystemData) gbe.ThinkResult {
    var it = gs.eventIter(c.EventConferBonus, "recipient_id", self.id); while (it.next()) |event| {
        switch (event.pickup_type) {
            .PowerUp => {
                p.playSample(gs, .PowerUp);
                self.player.attack_level = switch (self.player.attack_level) {
                    .One => c.Player.AttackLevel.Two,
                    else => c.Player.AttackLevel.Three,
                };
                self.player.last_pickup = ConstantTypes.PickupType.PowerUp;
            },
            .SpeedUp => {
                p.playSample(gs, .PowerUp);
                self.player.speed_level = switch (self.player.speed_level) {
                    .One => c.Player.SpeedLevel.Two,
                    else => c.Player.SpeedLevel.Three,
                };
                self.player.last_pickup = ConstantTypes.PickupType.SpeedUp;
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
    return .Remain;
}
