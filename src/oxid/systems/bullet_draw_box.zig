const draw = @import("../../common/draw.zig");
const game = @import("../game.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

pub fn run(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        bullet: *const c.Bullet,
    });
    while (it.next()) |self| {
        if (self.bullet.line_of_fire) |box| {
            p.eventDrawBox(gs, .{
                .box = box,
                .color = draw.black,
            });
        }
    }
}
