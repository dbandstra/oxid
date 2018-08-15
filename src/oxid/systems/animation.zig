const Gbe = @import("../../gbe.zig");
const GbeSystem = @import("../../gbe_system.zig");
const GameSession = @import("../game.zig").GameSession;
const getSimpleAnim = @import("../graphics.zig").getSimpleAnim;
const C = @import("../components.zig");
const GameUtil = @import("../util.zig");

const SystemData = struct{
  animation: *C.Animation,
};

pub const run = GbeSystem.build(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
  const animcfg = getSimpleAnim(self.animation.simple_anim);
  if (GameUtil.decrementTimer(&self.animation.frame_timer)) {
    self.animation.frame_index += 1;
    if (self.animation.frame_index >= animcfg.frames.len) {
      return false;
    }
    self.animation.frame_timer = animcfg.ticks_per_frame;
  }
  return true;
}
