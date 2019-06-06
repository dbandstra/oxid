const std = @import("std");
const gbe = @import("../../gbe.zig");
const GameSession = @import("../game.zig").GameSession;
const C = @import("../components.zig");
const input = @import("../input.zig");

const SystemData = struct {
    gc: *C.GameController,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    var it = gs.iter(C.EventInput); while (it.next()) |event| {
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
    var it = gs.iter(C.Monster); while (it.next()) |object| {
        if (!object.data.persistent) {
            gs.markEntityForRemoval(object.entity_id);
        }
    }

    if (gs.findFirst(C.GameController)) |gc| {
        gc.next_wave_timer = 1;
    }
}
