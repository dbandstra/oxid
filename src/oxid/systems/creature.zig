const game = @import("../game.zig");
const c = @import("../components.zig");

pub fn run(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        creature: *c.Creature,
    });
    while (it.next()) |self| {
        if (self.creature.invulnerability_timer > 0)
            self.creature.invulnerability_timer -= 1;
        if (self.creature.flinch_timer > 0)
            self.creature.flinch_timer -= 1;
    }
}
