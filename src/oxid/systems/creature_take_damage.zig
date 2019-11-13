const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const ConstantTypes = @import("../constant_types.zig");
const Constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");
const audio = @import("../audio.zig");

const SystemData = struct {
    id: gbe.EntityId,
    creature: *c.Creature,
    transform: *const c.Transform,
    monster: ?*const c.Monster,
    player: ?*c.Player,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) gbe.ThinkResult {
    if (self.creature.invulnerability_timer > 0) {
        return .Remain;
    }
    if (self.creature.god_mode) {
        return .Remain;
    }
    var it = gs.eventIter(c.EventTakeDamage, "self_id", self.id); while (it.next()) |event| {
        const amount = event.amount;
        if (self.creature.hit_points > amount) {
            p.playSample(gs, .MonsterImpact);
            self.creature.hit_points -= amount;
            self.creature.flinch_timer = Constants.duration60(4);
        } else if (self.creature.hit_points > 0) {
            self.creature.hit_points = 0;
            if (self.player) |self_player| {
                // player died
                p.playSample(gs, .PlayerScream);
                p.playSample(gs, .PlayerDeath);
                self_player.dying_timer = Constants.player_death_anim_time;
                _ = p.EventPlayerDied.spawn(gs, .{
                    .player_controller_id = self_player.player_controller_id,
                }) catch undefined;
                if (self_player.last_pickup) |pickup_type| {
                    _ = p.Pickup.spawn(gs, .{
                        .pos = self.transform.pos,
                        .pickup_type = pickup_type,
                    }) catch undefined;
                }
                return .Remain;
            } else {
                // something other than a player died
                if (self.monster) |self_monster| {
                    _ = p.EventMonsterDied.spawn(gs, .{}) catch undefined;
                    if (event.inflictor_player_controller_id) |player_controller_id| {
                        _ = p.EventAwardPoints.spawn(gs, .{
                            .player_controller_id = player_controller_id,
                            .points = self_monster.kill_points,
                        }) catch undefined;
                    }
                    if (self_monster.has_coin) {
                        _ = p.Pickup.spawn(gs, .{
                            .pos = self.transform.pos,
                            .pickup_type = .Coin,
                        }) catch undefined;
                    }
                }
                p.playSample(gs, .MonsterImpact);
                p.playSynth(gs, "Explosion", audio.ExplosionVoice.NoteParams {
                    .unused = false,
                });
                _ = p.Animation.spawn(gs, .{
                    .pos = self.transform.pos,
                    .simple_anim = .Explosion,
                    .z_index = Constants.z_index_explosion,
                }) catch undefined;
                return .RemoveSelf;
            }
        }
    }
    return .Remain;
}
