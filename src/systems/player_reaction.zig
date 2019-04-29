const gbe = @import("../common/gbe.zig");
const ConstantTypes = @import("../constant_types.zig");
const Audio = @import("../audio.zig");
const GameSession = @import("../game.zig").GameSession;
const C = @import("../components.zig");
const Prototypes = @import("../prototypes.zig");
const CoinVoice = @import("../audio/coin.zig").CoinVoice;

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
        _ = Prototypes.Sound.spawn(gs, Prototypes.Sound.Params {
          .duration = 2.0,
          .voice_params = Prototypes.Sound.VoiceParams {
            .Sample = Audio.Sample.PowerUp,
          },
        }) catch undefined;
        self.player.attack_level = switch (self.player.attack_level) {
          C.Player.AttackLevel.One => C.Player.AttackLevel.Two,
          else => C.Player.AttackLevel.Three,
        };
        self.player.last_pickup = ConstantTypes.PickupType.PowerUp;
      },
      ConstantTypes.PickupType.SpeedUp => {
        _ = Prototypes.Sound.spawn(gs, Prototypes.Sound.Params {
          .duration = 2.0,
          .voice_params = Prototypes.Sound.VoiceParams {
            .Sample = Audio.Sample.PowerUp,
          },
        }) catch undefined;
        self.player.speed_level = switch (self.player.speed_level) {
          C.Player.SpeedLevel.One => C.Player.SpeedLevel.Two,
          else => C.Player.SpeedLevel.Three,
        };
        self.player.last_pickup = ConstantTypes.PickupType.SpeedUp;
      },
      ConstantTypes.PickupType.LifeUp => {
        _ = Prototypes.Sound.spawn(gs, Prototypes.Sound.Params {
          .duration = 2.0,
          .voice_params = Prototypes.Sound.VoiceParams {
            .Sample = Audio.Sample.ExtraLife,
          },
        }) catch undefined;
        _ = Prototypes.EventAwardLife.spawn(gs,  C.EventAwardLife{
          .player_controller_id = self.player.player_controller_id,
        }) catch undefined;
      },
      ConstantTypes.PickupType.Coin => {
        _ = Prototypes.Sound.spawn(gs, Prototypes.Sound.Params {
          .duration = CoinVoice.SoundDuration,
          .voice_params = Prototypes.Sound.VoiceParams {
            .Coin = CoinVoice.Params {
              .freq_mul = 0.95 + 0.1 * gs.getRand().float(f32),
            },
          },
        }) catch undefined;
      },
    }
  }
  return true;
}
