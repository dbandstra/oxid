const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");
const util = @import("../util.zig");

const SystemData = struct {
    remove_timer: *c.RemoveTimer,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    if (util.decrementTimer(&self.remove_timer.timer)) {
        return false;
    }
    return true;
}
