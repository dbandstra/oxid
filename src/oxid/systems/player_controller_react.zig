const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const Constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

const SystemData = struct {
    id: gbe.EntityId,
    pc: *c.PlayerController,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    var it = gs.eventIter(c.EventPlayerDied, "player_controller_id", self.id); while (it.next()) |_| {
        if (self.pc.lives > 0) {
            self.pc.lives -= 1;
            if (self.pc.lives > 0) {
                self.pc.respawn_timer = Constants.player_respawn_time;
            } else {
                _ = p.EventPlayerOutOfLives.spawn(gs, c.EventPlayerOutOfLives {
                    .player_controller_id = self.id,
                }) catch undefined;
            }
        }
    }
    var it2 = gs.eventIter(c.EventAwardPoints, "player_controller_id", self.id); while (it2.next()) |event| {
        self.pc.score += event.points;
    }
    var it3 = gs.eventIter(c.EventAwardLife, "player_controller_id", self.id); while (it3.next()) |event| {
        self.pc.lives += 1;
    }
    return true;
}
