const drawing = @import("../../common/drawing.zig");
const game = @import("../game.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

pub fn run(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        player: *const c.Player,
    });
    while (it.next()) |self| {
        if (self.player.line_of_fire) |box| {
            p.spawnEventDrawBox(gs, .{
                .box = box,
                .color = drawing.pure_black,
            });
        }
    }
}
