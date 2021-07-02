const gbe = @import("gbe");
const game = @import("../game.zig");
const graphics = @import("../graphics.zig");
const c = @import("../components.zig");

pub fn run(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        id: gbe.EntityID,
        animation: *c.Animation,
    });
    while (it.next()) |self| {
        // when frame_timer completes, advance to the next animation frame, or
        // delete the entity if the animation is completed
        if (self.animation.frame_timer > 0) {
            self.animation.frame_timer -= 1;
            if (self.animation.frame_timer == 0) {
                const animcfg = graphics.getSimpleAnim(self.animation.simple_anim);
                if (self.animation.frame_index < animcfg.frames.len - 1) {
                    self.animation.frame_index += 1;
                    self.animation.frame_timer = animcfg.ticks_per_frame;
                } else {
                    gs.ecs.markForRemoval(self.id);
                }
            }
        }
    }
}
