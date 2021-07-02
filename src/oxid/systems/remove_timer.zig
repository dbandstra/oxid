const gbe = @import("gbe");
const game = @import("../game.zig");
const c = @import("../components.zig");

pub fn run(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        id: gbe.EntityID,
        remove_timer: *c.RemoveTimer,
    });
    while (it.next()) |self| {
        if (self.remove_timer.timer > 0) {
            self.remove_timer.timer -= 1;
            if (self.remove_timer.timer == 0)
                gs.ecs.markForRemoval(self.id);
        }
    }
}
