const Gbe = @import("../../gbe.zig");
const GbeSystem = @import("../../gbe_system.zig");
const ConstantTypes = @import("../constant_types.zig");
const Audio = @import("../audio.zig");
const GameSession = @import("../game.zig").GameSession;
const C = @import("../components.zig");
const Prototypes = @import("../prototypes.zig");

const SystemData = struct{
  id: Gbe.EntityId,
  creature: *const C.Creature,
  phys: *const C.PhysObject,
  player: *C.Player,
  transform: *const C.Transform,
};

pub const run = GbeSystem.build(GameSession, SystemData, playerReact);

fn playerReact(gs: *GameSession, self: SystemData) bool {
  var it = gs.gbe.eventIter(C.EventConferBonus, "recipient_id", self.id); while (it.next()) |event| {
    switch (event.pickup_type) {
      ConstantTypes.PickupType.PowerUp => {
        _ = Prototypes.EventSound.spawn(gs, C.EventSound{
          .sample = Audio.Sample.PowerUp,
        });
        self.player.attack_level = switch (self.player.attack_level) {
          C.Player.AttackLevel.One => C.Player.AttackLevel.Two,
          else => C.Player.AttackLevel.Three,
        };
        self.player.last_pickup = ConstantTypes.PickupType.PowerUp;
      },
      ConstantTypes.PickupType.SpeedUp => {
        _ = Prototypes.EventSound.spawn(gs, C.EventSound{
          .sample = Audio.Sample.PowerUp,
        });
        self.player.speed_level = switch (self.player.speed_level) {
          C.Player.SpeedLevel.One => C.Player.SpeedLevel.Two,
          else => C.Player.SpeedLevel.Three,
        };
        self.player.last_pickup = ConstantTypes.PickupType.SpeedUp;
      },
      ConstantTypes.PickupType.LifeUp => {
        _ = Prototypes.EventSound.spawn(gs, C.EventSound{
          .sample = Audio.Sample.ExtraLife,
        });
        _ = Prototypes.EventAwardLife.spawn(gs,  C.EventAwardLife{
          .player_controller_id = self.player.player_controller_id,
        });
      },
      ConstantTypes.PickupType.Coin => {
        _ = Prototypes.EventSound.spawn(gs, C.EventSound{
          .sample = Audio.Sample.Coin,
        });
      },
    }
  }
  return true;
}
