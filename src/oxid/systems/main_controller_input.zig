const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");

pub fn run(gs: *GameSession) void {
    var it = gs.ecs.iter(struct {
        mc: *c.MainController,
    });
    while (it.next()) |self| {
        const grs = if (self.mc.game_running_state) |*v| v else continue;

        var event_it = gs.ecs.componentIter(c.EventGameInput);

        while (event_it.next()) |event| {
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
}
