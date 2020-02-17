const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const Constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

pub fn run(gs: *GameSession) void {
    var it = gs.entityIter(struct {
        id: gbe.EntityId,
        pc: *c.PlayerController,
        inbox_award_points: gbe.Inbox(8, c.EventAwardPoints, "player_controller_id"),
        inbox_award_life: gbe.Inbox(8, c.EventAwardLife, "player_controller_id"),
        inbox_player_died: gbe.Inbox(1, c.EventPlayerDied, "player_controller_id"),
    });

    while (it.next()) |self| {
        for (self.inbox_award_points.all) |event| {
            self.pc.score += event.points;
        }

        for (self.inbox_award_life.all) |_| {
            self.pc.lives += 1;
        }

        if (self.inbox_player_died.one != null and self.pc.lives > 0) {
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
