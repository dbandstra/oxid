const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const Constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

const SystemData = struct {
    id: gbe.EntityId,
    pc: *c.PlayerController,
};

pub fn run(gs: *GameSession) void {
    var it = gs.entityIter(SystemData);

    while (it.next()) |self| {
        var event_it = gs.eventIter(c.EventPlayerDied,
            "player_controller_id", self.id);
        while (event_it.next()) |_| {
            if (self.pc.lives > 0) {
                self.pc.lives -= 1;
                if (self.pc.lives > 0) {
                    self.pc.respawn_timer = Constants.player_respawn_time;
                } else {
                    _ = p.EventPlayerOutOfLives.spawn(gs, .{
                        .player_controller_id = self.id,
                    }) catch undefined;
                }
            }
        }

        var event_it2 = gs.eventIter(c.EventAwardPoints,
            "player_controller_id", self.id);
        while (event_it2.next()) |event| {
            self.pc.score += event.points;
        }

        var event_it3 = gs.eventIter(c.EventAwardLife,
            "player_controller_id", self.id);
        while (event_it3.next()) |event| {
            self.pc.lives += 1;
        }
    }
}
