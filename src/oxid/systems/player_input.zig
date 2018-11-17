const std = @import("std");
const Draw = @import("../../draw.zig");
const Gbe = @import("../../gbe.zig");
const GbeSystem = @import("../../gbe_system.zig");
const GameSession = @import("../game.zig").GameSession;
const Constants = @import("../constants.zig");
const C = @import("../components.zig");
const Prototypes = @import("../prototypes.zig");
const GameUtil = @import("../util.zig");
const input = @import("../input.zig");
const Graphic = @import("../graphics.zig").Graphic;
const getSimpleAnim = @import("../graphics.zig").getSimpleAnim;

const SystemData = struct{
  player: *C.Player,
  creature: *C.Creature,
};

pub const run = GbeSystem.build(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
  var it = gs.iter(C.EventInput); while (it.next()) |event| {
    switch (event.data.command) {
      input.Command.Up => {
        self.player.in_up = event.data.down;
      },
      input.Command.Down => {
        self.player.in_down = event.data.down;
      },
      input.Command.Left => {
        self.player.in_left = event.data.down;
      },
      input.Command.Right => {
        self.player.in_right = event.data.down;
      },
      input.Command.Shoot => {
        self.player.in_shoot = event.data.down;
      },
      input.Command.ToggleGodMode => {
        if (event.data.down) {
          self.creature.god_mode = !self.creature.god_mode;
        }
      },
      else => {},
    }
  }
  return true;
}
