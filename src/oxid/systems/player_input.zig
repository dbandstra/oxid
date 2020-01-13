const std = @import("std");
const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");

const SystemData = struct {
    player: *c.Player,
    creature: *c.Creature,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) gbe.ThinkResult {
    var it = gs.iter(c.EventGameInput); while (it.next()) |event| {
        if (event.player_number != self.player.player_number) {
            continue;
        }
        switch (event.command) {
            .Up => {
                self.player.in_up = event.down;
            },
            .Down => {
                self.player.in_down = event.down;
            },
            .Left => {
                self.player.in_left = event.down;
            },
            .Right => {
                self.player.in_right = event.down;
            },
            .Shoot => {
                self.player.in_shoot = event.down;
            },
            .ToggleGodMode => {
                if (event.down) {
                    self.creature.god_mode = !self.creature.god_mode;
                }
            },
            else => {},
        }
    }
    return .Remain;
}
