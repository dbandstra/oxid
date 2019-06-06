const gbe = @import("../common/gbe.zig");
const GameSession = @import("../game.zig").GameSession;
const C = @import("../components.zig");
const GameUtil = @import("../util.zig");

const SystemData = struct{
    remove_timer: *C.RemoveTimer,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    if (GameUtil.decrementTimer(&self.remove_timer.timer)) {
        return false;
    }
    return true;
}
