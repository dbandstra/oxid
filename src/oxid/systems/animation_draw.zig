const std = @import("std");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");
const p = @import("../prototypes.zig");
const getSimpleAnim = @import("../graphics.zig").getSimpleAnim;

pub fn run(gs: *GameSession) void {
    var it = gs.ecs.iter(struct {
        transform: *const c.Transform,
        animation: *const c.Animation,
    });
    while (it.next()) |self| {
        const animcfg = getSimpleAnim(self.animation.simple_anim);

        std.debug.assert(self.animation.frame_index < animcfg.frames.len);

        _ = p.EventDraw.spawn(gs, .{
            .pos = self.transform.pos,
            .graphic = animcfg.frames[self.animation.frame_index],
            .transform = .identity,
            .z_index = self.animation.z_index,
        }) catch undefined;
    }
}
