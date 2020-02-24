const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");

pub fn run(gs: *GameSession) void {
    var it = gs.ecs.entityIter(struct {
        gc: *c.GameController,
    });

    while (it.next()) |self| {
        var event_it = gs.ecs.iter(c.EventGameInput);

        while (event_it.next()) |event| {
            switch (event.command) {
                .KillAllMonsters => {
                    if (event.down) {
                        killAllMonsters(gs);
                    }
                },
                else => {},
            }
        }
    }
}

pub fn killAllMonsters(gs: *GameSession) void {
    var it = gs.ecs.entityIter(struct {
        id: gbe.EntityId,
        monster: *const c.Monster,
    });

    while (it.next()) |entry| {
        if (!entry.monster.persistent) {
            continue;
        }
        gs.ecs.markEntityForRemoval(entry.id);
    }

    if (gs.ecs.findFirst(c.GameController)) |gc| {
        gc.next_wave_timer = 1;
    }
}
