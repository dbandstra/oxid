const gbe = @import("gbe");
const game = @import("../game.zig");
const c = @import("../components.zig");
const util = @import("../util.zig");

pub fn run(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        id: gbe.EntityId,
        remove_timer: *c.RemoveTimer,
    });
    while (it.next()) |self| {
        if (util.decrementTimer(&self.remove_timer.timer)) {
            gs.ecs.markForRemoval(self.id);
        }
    }
}
