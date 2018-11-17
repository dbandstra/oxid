const std = @import("std");
const Draw = @import("../../draw.zig");
const Gbe = @import("../../gbe.zig");
const GbeSystem = @import("../../gbe_system.zig");
const GameSession = @import("../game.zig").GameSession;
const Constants = @import("../constants.zig");
const C = @import("../components.zig");
const Prototypes = @import("../prototypes.zig");
const GameUtil = @import("../util.zig");
const Graphic = @import("../graphics.zig").Graphic;
const getSimpleAnim = @import("../graphics.zig").getSimpleAnim;

const SystemData = struct{
  transform: *const C.Transform,
  animation: *const C.Animation,
};

pub const run = GbeSystem.build(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
  const animcfg = getSimpleAnim(self.animation.simple_anim);
  std.debug.assert(self.animation.frame_index < animcfg.frames.len);
  _ = Prototypes.EventDraw.spawn(gs, C.EventDraw{
    .pos = self.transform.pos,
    .graphic = animcfg.frames[self.animation.frame_index],
    .transform = Draw.Transform.Identity,
    .z_index = self.animation.z_index,
  });
  return true;
}
