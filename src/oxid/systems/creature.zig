const gbe = @import("../../gbe.zig");
const GameSession = @import("../game.zig").GameSession;
const C = @import("../components.zig");
const util = @import("../util.zig");

const SystemData = struct {
    creature: *C.Creature,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    _ = util.decrementTimer(&self.creature.invulnerability_timer);
    _ = util.decrementTimer(&self.creature.flinch_timer);
    return true;
}
