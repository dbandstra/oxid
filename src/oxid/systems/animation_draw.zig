const std = @import("std");
const game = @import("../game.zig");
const graphics = @import("../graphics.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

pub fn run(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        transform: *const c.Transform,
        animation: *const c.Animation,
    });
    while (it.next()) |self| {
        const animcfg = graphics.getSimpleAnim(self.animation.simple_anim);

        std.debug.assert(self.animation.frame_index < animcfg.frames.len);

        _ = p.EventDraw.spawn(gs, .{
            .pos = self.transform.pos,
            .graphic = animcfg.frames[self.animation.frame_index],
            .transform = .identity,
            .z_index = self.animation.z_index,
        }) catch undefined;
    }
}
