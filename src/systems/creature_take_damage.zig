const gbe = @import("../common/gbe.zig");
const Audio = @import("../audio.zig");
const GameSession = @import("../game.zig").GameSession;
const SimpleAnim = @import("../graphics.zig").SimpleAnim;
const ConstantTypes = @import("../constant_types.zig");
const Constants = @import("../constants.zig");
const C = @import("../components.zig");
const Prototypes = @import("../prototypes.zig");
const ExplosionVoice = @import("../audio/explosion.zig").ExplosionVoice;
const SampleVoice = @import("../audio/sample.zig").SampleVoice;

const SystemData = struct{
  id: gbe.EntityId,
  creature: *C.Creature,
  transform: *const C.Transform,
  monster: ?*const C.Monster,
  player: ?*C.Player,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
  if (self.creature.invulnerability_timer > 0) {
    return true;
  }
  if (self.creature.god_mode) {
    return true;
  }
  var it = gs.eventIter(C.EventTakeDamage, "self_id", self.id); while (it.next()) |event| {
    const amount = event.amount;
    if (self.creature.hit_points > amount) {
      Prototypes.spawnPointSound(gs, SampleVoice, C.EventSoundU {
        .Sample = SampleVoice.Params {
          .wav = Audio.samples.monster_impact,
        },
      });
      self.creature.hit_points -= amount;
      self.creature.flinch_timer = 4;
    } else if (self.creature.hit_points > 0) {
      self.creature.hit_points = 0;
      if (self.player) |self_player| {
        // player died
        Prototypes.spawnPointSound(gs, SampleVoice, C.EventSoundU {
          .Sample = SampleVoice.Params {
            .wav = Audio.samples.player_scream,
          },
        });
        Prototypes.spawnPointSound(gs, SampleVoice, C.EventSoundU {
          .Sample = SampleVoice.Params {
            .wav = Audio.samples.player_death,
          },
        });
        self_player.dying_timer = Constants.PlayerDeathAnimTime;
        _ = Prototypes.EventPlayerDied.spawn(gs, C.EventPlayerDied{
          .player_controller_id = self_player.player_controller_id,
        }) catch undefined;
        if (self_player.last_pickup) |pickup_type| {
          _ = Prototypes.Pickup.spawn(gs, Prototypes.Pickup.Params{
            .pos = self.transform.pos,
            .pickup_type = pickup_type,
          }) catch undefined;
        }
        return true;
      } else {
        // something other than a player died
        if (self.monster) |self_monster| {
          _ = Prototypes.EventMonsterDied.spawn(gs, C.EventMonsterDied{}) catch undefined;
          if (event.inflictor_player_controller_id) |player_controller_id| {
            _ = Prototypes.EventAwardPoints.spawn(gs, C.EventAwardPoints{
              .player_controller_id = player_controller_id,
              .points = self_monster.kill_points,
            }) catch undefined;
          }
          if (self_monster.has_coin) {
            _ = Prototypes.Pickup.spawn(gs, Prototypes.Pickup.Params{
              .pos = self.transform.pos,
              .pickup_type = ConstantTypes.PickupType.Coin,
            }) catch undefined;
          }
        }
        Prototypes.spawnPointSound(gs, SampleVoice, C.EventSoundU {
          .Sample = SampleVoice.Params {
            .wav = Audio.samples.monster_impact,
          },
        });
        Prototypes.spawnPointSound(gs, ExplosionVoice, C.EventSoundU {
          .Explosion = ExplosionVoice.Params {},
        });
        _ = Prototypes.Animation.spawn(gs, Prototypes.Animation.Params{
          .pos = self.transform.pos,
          .simple_anim = SimpleAnim.Explosion,
          .z_index = Constants.ZIndexExplosion,
        }) catch undefined;
        return false;
      }
    }
  }
  return true;
}
