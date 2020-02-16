const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");
const util = @import("../util.zig");

pub fn run(gs: *GameSession) void {
    var it = gs.entityIter(struct {
        id: gbe.EntityId,
        remove_timer: *c.RemoveTimer,
    });

    while (it.next()) |self| {
        if (util.decrementTimer(&self.remove_timer.timer)) {
            gs.markEntityForRemoval(self.id);
        }
    }
}
