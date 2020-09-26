const gbe = @import("gbe");
const game = @import("../game.zig");
const c = @import("../components.zig");

pub fn run(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        mc: *c.MainController,
        inbox: gbe.Inbox(16, c.EventGameInput, null),
    });
    while (it.next()) |self| {
        const grs = if (self.mc.game_running_state) |*v| v else continue;

        for (self.inbox.all()) |event| {
            switch (event.command) {
                .toggle_draw_boxes => {
                    if (event.down) {
                        grs.render_move_boxes = !grs.render_move_boxes;
                    }
                },
                else => {},
            }
        }
    }
}
