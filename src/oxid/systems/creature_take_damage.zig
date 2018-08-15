const Gbe = @import("../../gbe.zig");
const GbeSystem = @import("../../gbe_system.zig");
const Audio = @import("../audio.zig");
const GameSession = @import("../game.zig").GameSession;
const SimpleAnim = @import("../graphics.zig").SimpleAnim;
const ConstantTypes = @import("../constant_types.zig");
const Constants = @import("../constants.zig");
const C = @import("../components.zig");
const Prototypes = @import("../prototypes.zig");

const SystemData = struct{
  id: Gbe.EntityId,
  creature: *C.Creature,
  transform: *C.Transform,
  monster: ?*C.Monster,
  player: ?*C.Player,
};

pub const run = GbeSystem.build(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
  if (self.creature.invulnerability_timer > 0) {
    return true;
  }
  if (gs.god_mode and self.player != null) {
    return true;
  }
  var it = gs.gbe.eventIter(C.EventTakeDamage, "self_id", self.id); while (it.next()) |event| {
    const amount = event.amount;
    if (self.creature.hit_points > amount) {
      _ = Prototypes.EventSound.spawn(gs, C.EventSound{
        .sample = Audio.Sample.MonsterImpact,
      });
      self.creature.hit_points -= amount;
    } else if (self.creature.hit_points > 0) {
      self.creature.hit_points = 0;
      if (self.player) |self_player| {
        // player died
        _ = Prototypes.EventSound.spawn(gs, C.EventSound{
          .sample = Audio.Sample.PlayerScream,
        });
        _ = Prototypes.EventSound.spawn(gs, C.EventSound{
          .sample = Audio.Sample.PlayerDeath,
        });
        self_player.dying_timer = Constants.PlayerDeathAnimTime;
        _ = Prototypes.EventPlayerDied.spawn(gs, C.EventPlayerDied{
          .player_controller_id = self_player.player_controller_id,
        });
        if (self_player.last_pickup) |pickup_type| {
          _ = Prototypes.Pickup.spawn(gs, Prototypes.Pickup.Params{
            .pos = self.transform.pos,
            .pickup_type = pickup_type,
          });
        }
        return true;
      } else {
        if (self.monster) |self_monster| {
          _ = Prototypes.EventSound.spawn(gs, C.EventSound{
            .sample = Audio.Sample.MonsterImpact,
          });
          _ = Prototypes.EventSound.spawn(gs, C.EventSound{
            .sample = Audio.Sample.MonsterDeath,
          });
          _ = Prototypes.EventMonsterDied.spawn(gs, C.EventMonsterDied{
            .unused = 0,
          });
          if (event.inflictor_player_controller_id) |player_controller_id| {
            _ = Prototypes.EventAwardPoints.spawn(gs, C.EventAwardPoints{
              .player_controller_id = player_controller_id,
              .points = self_monster.kill_points,
            });
          }
          if (self_monster.has_coin) {
            _ = Prototypes.Pickup.spawn(gs, Prototypes.Pickup.Params{
              .pos = self.transform.pos,
              .pickup_type = ConstantTypes.PickupType.Coin,
            });
          }
        }
        // something other than a player died
        _ = Prototypes.Animation.spawn(gs, Prototypes.Animation.Params{
          .pos = self.transform.pos,
          .simple_anim = SimpleAnim.Explosion,
          .z_index = Constants.ZIndexExplosion,
        });
        return false;
      }
    }
  }
  return true;
}
