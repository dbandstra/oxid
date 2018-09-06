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
const killAllMonsters = @import("../functions/kill_all_monsters.zig").killAllMonsters;

const SystemData = struct{
  gc: *C.GameController,
};

pub const run = GbeSystem.build(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
  var it = gs.gbe.iter(C.EventInput); while (it.next()) |event| {
    switch (event.data.command) {
      input.Command.TogglePaused => {
        if (event.data.down) {
          self.gc.paused = !self.gc.paused;
        }
      },
      input.Command.ToggleDrawBoxes => {
        if (event.data.down) {
          self.gc.render_move_boxes = !self.gc.render_move_boxes;
        }
      },
      input.Command.FastForward => {
        self.gc.fast_forward = event.data.down;
      },
      input.Command.KillAllMonsters => {
        if (event.data.down) {
          killAllMonsters(gs);
        }
      },
      else => {},
    }
  }
  return true;
}
