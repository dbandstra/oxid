const std = @import("std");
const gbe = @import("../../gbe.zig");
const GameSession = @import("../game.zig").GameSession;
const C = @import("../components.zig");
const input = @import("../input.zig");

const SystemData = struct {
    player: *C.Player,
    creature: *C.Creature,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    var it = gs.iter(C.EventInput); while (it.next()) |event| {
        switch (event.data.command) {
            input.Command.Up => {
                self.player.in_up = event.data.down;
            },
            input.Command.Down => {
                self.player.in_down = event.data.down;
            },
            input.Command.Left => {
                self.player.in_left = event.data.down;
            },
            input.Command.Right => {
                self.player.in_right = event.data.down;
            },
            input.Command.Shoot => {
                self.player.in_shoot = event.data.down;
            },
            input.Command.ToggleGodMode => {
                if (event.data.down) {
                    self.creature.god_mode = !self.creature.god_mode;
                }
            },
            else => {},
        }
    }
    return true;
}
