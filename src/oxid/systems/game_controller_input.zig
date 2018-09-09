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
  gc: *C.GameController,
};

pub const run = GbeSystem.build(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
  var it = gs.iter(C.EventInput); while (it.next()) |event| {
    switch (event.data.command) {
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

pub fn killAllMonsters(gs: *GameSession) void {
  var it = gs.iter(C.Monster); while (it.next()) |object| {
    if (!object.data.persistent) {
      gs.markEntityForRemoval(object.entity_id);
    }
  }

  if (gs.iter(C.GameController).next()) |object| {
    object.data.next_wave_timer = 1;
  }
}
