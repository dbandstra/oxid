const std = @import("std");
const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");

const SystemData = struct {
    gc: *c.GameController,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) gbe.ThinkResult {
    var it = gs.iter(c.EventGameInput); while (it.next()) |event| {
        switch (event.command) {
            .KillAllMonsters => {
                if (event.down) {
                    killAllMonsters(gs);
                }
            },
            else => {},
        }
    }
    return .Remain;
}

pub fn killAllMonsters(gs: *GameSession) void {
    var it = gs.entityIter(struct {
        id: gbe.EntityId,
        monster: *const c.Monster,
    });
    while (it.next()) |entry| {
        if (entry.monster.persistent) continue;
        gs.markEntityForRemoval(entry.id);
    }

    if (gs.findFirst(c.GameController)) |gc| {
        gc.next_wave_timer = 1;
    }
}
