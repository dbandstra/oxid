const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

const SystemData = struct {
    mc: *c.MainController,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    var it = gs.iter(c.EventPostScore); while (it.next()) |object| {
        const score = object.data.score;
        if (score > self.mc.high_score) {
            self.mc.high_score = score;
            self.mc.new_high_score = true;
            _ = p.EventSaveHighScore.spawn(gs, c.EventSaveHighScore {
                .high_score = score,
            }) catch undefined;
        } else {
            self.mc.new_high_score = false;
        }
    }
    return true;
}
