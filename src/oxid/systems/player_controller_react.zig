const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const Constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

pub fn run(gs: *GameSession) void {
    handlePlayerDied(gs);
    handleAwardPoints(gs);
    handleAwardLife(gs);
}

// FIXME - weird edge condition here if the player dies and picks up a 1-up
// on the same frame

fn handlePlayerDied(gs: *GameSession) void {
    var it = gs.eventIter(c.EventPlayerDied, "player_controller_id", struct {
        id: gbe.EntityId,
        pc: *c.PlayerController,
    });

    while (it.next()) |entry| {
        const self = entry.subject;

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
}

fn handleAwardPoints(gs: *GameSession) void {
    var it = gs.eventIter(c.EventAwardPoints, "player_controller_id", struct {
        pc: *c.PlayerController,
    });

    while (it.next()) |entry| {
        const self = entry.subject;
        const event = entry.event;

        self.pc.score += event.points;
    }
}

fn handleAwardLife(gs: *GameSession) void {
    var it = gs.eventIter(c.EventAwardLife, "player_controller_id", struct {
        pc: *c.PlayerController,
    });

    while (it.next()) |entry| {
        const self = entry.subject;

        self.pc.lives += 1;
    }
}
