const gbe = @import("../common/gbe.zig");
const ConstantTypes = @import("../constant_types.zig");
const Audio = @import("../audio.zig");
const GameSession = @import("../game.zig").GameSession;
const C = @import("../components.zig");
const Prototypes = @import("../prototypes.zig");
const CoinVoice = @import("../audio/coin.zig").CoinVoice;
const SampleVoice = @import("../audio/sample.zig").SampleVoice;

const SystemData = struct{
  id: gbe.EntityId,
  creature: *const C.Creature,
  phys: *const C.PhysObject,
  player: *C.Player,
  transform: *const C.Transform,
};

pub const run = gbe.buildSystem(GameSession, SystemData, playerReact);

fn playerReact(gs: *GameSession, self: SystemData) bool {
  var it = gs.eventIter(C.EventConferBonus, "recipient_id", self.id); while (it.next()) |event| {
    switch (event.pickup_type) {
      ConstantTypes.PickupType.PowerUp => {
        Prototypes.spawnPointSound(gs, SampleVoice, Audio.samples.power_up);
        self.player.attack_level = switch (self.player.attack_level) {
          C.Player.AttackLevel.One => C.Player.AttackLevel.Two,
          else => C.Player.AttackLevel.Three,
        };
        self.player.last_pickup = ConstantTypes.PickupType.PowerUp;
      },
      ConstantTypes.PickupType.SpeedUp => {
        Prototypes.spawnPointSound(gs, SampleVoice, Audio.samples.power_up);
        self.player.speed_level = switch (self.player.speed_level) {
          C.Player.SpeedLevel.One => C.Player.SpeedLevel.Two,
          else => C.Player.SpeedLevel.Three,
        };
        self.player.last_pickup = ConstantTypes.PickupType.SpeedUp;
      },
      ConstantTypes.PickupType.LifeUp => {
        Prototypes.spawnPointSound(gs, SampleVoice, Audio.samples.extra_life);
        _ = Prototypes.EventAwardLife.spawn(gs,  C.EventAwardLife{
          .player_controller_id = self.player.player_controller_id,
        }) catch undefined;
      },
      ConstantTypes.PickupType.Coin => {
        Prototypes.spawnPointSound(gs, CoinVoice, null);
      },
    }
  }
  return true;
}
