const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");

const SystemData = struct {
    mc: *c.MainController,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) gbe.ThinkResult {
    if (self.mc.game_running_state) |*grs| {
        var it = gs.iter(c.EventGameInput); while (it.next()) |event| {
            switch (event.command) {
                .ToggleDrawBoxes => {
                    if (event.down) {
                        grs.render_move_boxes = !grs.render_move_boxes;
                    }
                },
                else => {},
            }
        }
    }

    return .Remain;
}
