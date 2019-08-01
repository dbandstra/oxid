const std = @import("std");
const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");

const SystemData = struct {
    player: *c.Player,
    creature: *c.Creature,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    var it = gs.iter(c.EventGameInput); while (it.next()) |event| {
        switch (event.data.command) {
            .Up => {
                self.player.in_up = event.data.down;
            },
            .Down => {
                self.player.in_down = event.data.down;
            },
            .Left => {
                self.player.in_left = event.data.down;
            },
            .Right => {
                self.player.in_right = event.data.down;
            },
            .Shoot => {
                self.player.in_shoot = event.data.down;
            },
            .ToggleGodMode => {
                if (event.data.down) {
                    self.creature.god_mode = !self.creature.god_mode;
                }
            },
            else => {},
        }
    }
    return true;
}
