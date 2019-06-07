const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const getSimpleAnim = @import("../graphics.zig").getSimpleAnim;
const c = @import("../components.zig");
const util = @import("../util.zig");

const SystemData = struct {
    animation: *c.Animation,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    const animcfg = getSimpleAnim(self.animation.simple_anim);
    if (util.decrementTimer(&self.animation.frame_timer)) {
        if (self.animation.frame_index >= animcfg.frames.len - 1) {
            return false;
        }
        self.animation.frame_index += 1;
        self.animation.frame_timer = animcfg.ticks_per_frame;
    }
    return true;
}
