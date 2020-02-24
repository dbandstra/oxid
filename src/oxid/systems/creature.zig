const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");
const util = @import("../util.zig");

pub fn run(gs: *GameSession) void {
    var it = gs.ecs.entityIter(struct {
        creature: *c.Creature,
    });

    while (it.next()) |self| {
        _ = util.decrementTimer(&self.creature.invulnerability_timer);
        _ = util.decrementTimer(&self.creature.flinch_timer);
    }
}
