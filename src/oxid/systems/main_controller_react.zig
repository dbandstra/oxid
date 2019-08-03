const std = @import("std");
const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const Constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

const SystemData = struct {
    mc: *c.MainController,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    var it = gs.iter(c.EventPostScore); while (it.next()) |object| {
        self.mc.new_high_score = false;

        // insert the score somewhere in the high score list
        const new_score = object.data.score;

        // the list is always sorted highest to lowest
        var i: usize = 0; while (i < Constants.num_high_scores) : (i += 1) {
            if (new_score > self.mc.high_scores[i]) {
                // insert the new score here
                std.mem.copyBackwards(u32,
                    self.mc.high_scores[i + 1..Constants.num_high_scores],
                    self.mc.high_scores[i..Constants.num_high_scores - 1]
                );

                self.mc.high_scores[i] = new_score;
                if (i == 0) {
                    self.mc.new_high_score = true;
                }

                _ = p.EventSystemCommand.spawn(gs, c.EventSystemCommand {
                    .SaveHighScores = self.mc.high_scores,
                }) catch undefined;

                break;
            }
        }
    }
    return true;
}
