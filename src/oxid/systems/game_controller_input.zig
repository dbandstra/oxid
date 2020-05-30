const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");

pub fn run(gs: *GameSession) void {
    var it = gs.ecs.iter(struct {
        gc: *c.GameController,
        inbox: gbe.Inbox(16, c.EventGameInput, null),
    });
    while (it.next()) |self| {
        for (self.inbox.all()) |event| {
            switch (event.command) {
                .kill_all_monsters => {
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
    var it = gs.ecs.iter(struct {
        id: gbe.EntityId,
        monster: *const c.Monster,
    });
    while (it.next()) |self| {
        if (self.monster.persistent) {
            continue;
        }
        gs.ecs.markForRemoval(self.id);
    }

    if (gs.ecs.findFirstComponent(c.GameController)) |gc| {
        gc.next_wave_timer = 1;
    }
}
