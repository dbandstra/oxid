const gbe = @import("gbe");
const game = @import("../game.zig");
const constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

pub fn run(gs: *game.Session) void {
    handleAwardPoints(gs);
    handleAwardLife(gs);
    handlePlayerDied(gs);
}

fn handleAwardPoints(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        pc: *c.PlayerController,
        inbox: gbe.Inbox(8, c.EventAwardPoints, "player_controller_id"),
    });
    while (it.next()) |self| {
        for (self.inbox.all()) |event| {
            self.pc.score += event.points;
        }
    }
}

fn handleAwardLife(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        pc: *c.PlayerController,
        inbox: gbe.Inbox(8, c.EventAwardLife, "player_controller_id"),
    });
    while (it.next()) |self| {
        for (self.inbox.all()) |_| {
            self.pc.lives += 1;
        }
    }
}

fn handlePlayerDied(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        id: gbe.EntityId,
        pc: *c.PlayerController,
        inbox: gbe.Inbox(1, c.EventPlayerDied, "player_controller_id"),
    });
    while (it.next()) |self| {
        if (self.pc.lives > 0) {
            self.pc.lives -= 1;
            if (self.pc.lives > 0) {
                self.pc.respawn_timer = constants.player_respawn_time;
            } else {
                p.spawnEventPlayerOutOfLives(gs, .{
                    .player_controller_id = self.id,
                });
            }
        }
    }
}
