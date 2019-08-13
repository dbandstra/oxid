const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

const SystemData = struct {
    mc: *c.MainController,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    var it = gs.iter(c.EventRawInput); while (it.next()) |event| {
        if (self.mc.menu_stack_len == 0) {
            // game mode
            if (event.data.game_command) |command| {
                _ = p.EventGameInput.spawn(gs, c.EventGameInput {
                    .command = command,
                    .down = event.data.down,
                }) catch undefined;
            }
        } else {
            // menu mode
            _ = p.EventMenuInput.spawn(gs, c.EventMenuInput {
                .command = event.data.menu_command,
                .key = event.data.key,
                .down = event.data.down,
            }) catch undefined;
        }
    }
    return true;
}
