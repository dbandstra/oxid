const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const Constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

pub fn run(gs: *GameSession) void {
    var it = gs.entityIter(struct {
        id: gbe.EntityId,
        pc: *c.PlayerController,
        inbox_player_died: gbe.Inbox(c.EventPlayerDied, "player_controller_id"),
        inbox_award_points: gbe.Inbox(c.EventAwardPoints, "player_controller_id"),
        inbox_award_life: gbe.Inbox(c.EventAwardLife, "player_controller_id"),
    });

    while (it.next()) |self| {
        if (self.inbox_player_died.head) |event| {
            if (self.pc.lives >= 0) {
                self.pc.lives -= 1;
                if (self.pc.lives > 0) {
                    self.pc.respawn_timer = Constants.player_respawn_time;
                } else {
                    _ = p.EventPlayerOutOfLives.spawn(gs, .{
                        .player_controller_id = self.id,
                    }) catch undefined;
                }
                continue;
            }
        }

        if (self.inbox_award_points.head) |event| {
            self.pc.score += event.points;
        }

        if (self.inbox_award_life.head) |event| {
            self.pc.lives += 1;
        }
    }
}
