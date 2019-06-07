const std = @import("std");
const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");
const input = @import("../input.zig");

const SystemData = struct {
    gc: *c.GameController,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    var it = gs.iter(c.EventInput); while (it.next()) |event| {
        switch (event.data.command) {
            input.Command.KillAllMonsters => {
                if (event.data.down) {
                    killAllMonsters(gs);
                }
            },
            else => {},
        }
    }
    return true;
}

pub fn killAllMonsters(gs: *GameSession) void {
    var it = gs.iter(c.Monster); while (it.next()) |object| {
        if (!object.data.persistent) {
            gs.markEntityForRemoval(object.entity_id);
        }
    }

    if (gs.findFirst(c.GameController)) |gc| {
        gc.next_wave_timer = 1;
    }
}
