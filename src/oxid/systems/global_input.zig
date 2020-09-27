const game = @import("../game.zig");
const c = @import("../components.zig");

pub fn run(gs: *game.Session) void {
    const grs = if (gs.running_state) |*v| v else return;

    var it = gs.ecs.componentIter(c.EventGameInput);
    while (it.next()) |event| {
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
