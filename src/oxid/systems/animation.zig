const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const getSimpleAnim = @import("../graphics.zig").getSimpleAnim;
const c = @import("../components.zig");
const util = @import("../util.zig");

pub fn run(gs: *GameSession) void {
    var it = gs.ecs.iter(struct {
        id: gbe.EntityId,
        animation: *c.Animation,
    });
    while (it.next()) |self| {
        const animcfg = getSimpleAnim(self.animation.simple_anim);

        if (util.decrementTimer(&self.animation.frame_timer)) {
            if (self.animation.frame_index >= animcfg.frames.len - 1) {
                gs.ecs.markForRemoval(self.id);
                continue;
            }
            self.animation.frame_index += 1;
            self.animation.frame_timer = animcfg.ticks_per_frame;
        }
    }
}
