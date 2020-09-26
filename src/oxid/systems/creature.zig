const game = @import("../game.zig");
const c = @import("../components.zig");
const util = @import("../util.zig");

pub fn run(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        creature: *c.Creature,
    });
    while (it.next()) |self| {
        _ = util.decrementTimer(&self.creature.invulnerability_timer);
        _ = util.decrementTimer(&self.creature.flinch_timer);
    }
}
