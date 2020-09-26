const gbe = @import("gbe");
const game = @import("../game.zig");
const graphics = @import("../graphics.zig");
const c = @import("../components.zig");
const util = @import("../util.zig");

pub fn run(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        id: gbe.EntityId,
        animation: *c.Animation,
    });
    while (it.next()) |self| {
        const animcfg = graphics.getSimpleAnim(self.animation.simple_anim);

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
