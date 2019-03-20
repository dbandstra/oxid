const std = @import("std");
const Draw = @import("../common/draw.zig");
const gbe = @import("../common/gbe.zig");
const GameSession = @import("../game.zig").GameSession;
const Constants = @import("../constants.zig");
const C = @import("../components.zig");
const Prototypes = @import("../prototypes.zig");
const GameUtil = @import("../util.zig");
const Graphic = @import("../graphics.zig").Graphic;
const getSimpleAnim = @import("../graphics.zig").getSimpleAnim;

const SystemData = struct{
  phys: *const C.PhysObject,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
  const int = self.phys.internal;
  _ = Prototypes.EventDrawBox.spawn(gs, C.EventDrawBox{
    .box = int.move_bbox,
    .color = Draw.Color{
      .r = @intCast(u8, 64 + ((int.group_index * 41) % 192)),
      .g = @intCast(u8, 64 + ((int.group_index * 901) % 192)),
      .b = @intCast(u8, 64 + ((int.group_index * 10031) % 192)),
      .a = 255,
    },
  });
  return true;
}
