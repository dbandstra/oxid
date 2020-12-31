const gbe = @import("gbe");
const game = @import("../game.zig");
const constants = @import("../constants.zig");
const c = @import("../components.zig");

pub fn run(gs: *game.Session) void {
    globalInput(gs);
    playerInput(gs);
}

fn globalInput(gs: *game.Session) void {
    const grs = if (gs.running_state) |*v| v else return;

    var it = gs.ecs.componentIter(c.EventGameInput);
    while (it.next()) |event| {
        switch (event.command) {
            .toggle_draw_boxes => {
                if (event.down)
                    grs.render_move_boxes = !grs.render_move_boxes;
            },
            .kill_all_monsters => {
                if (event.down)
                    killAllMonsters(gs);
            },
            else => {},
        }
    }
}

fn killAllMonsters(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        id: gbe.EntityId,
        monster: *const c.Monster,
    });
    while (it.next()) |self| {
        if (constants.getMonsterValues(self.monster.monster_type).persistent)
            continue;
        gs.ecs.markForRemoval(self.id);
    }

    if (gs.ecs.componentIter(c.GameController).next()) |gc| {
        gc.next_wave_timer = 1;
    }
}

fn playerInput(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        player: *c.Player,
        creature: *c.Creature,
        inbox: gbe.Inbox(16, c.EventGameInput, null),
    });
    while (it.next()) |self| {
        for (self.inbox.all()) |event| {
            // TODO is it possible to have the event point right to the player id?
            if (event.player_number != self.player.player_number)
                continue;
            switch (event.command) {
                .up => {
                    self.player.in_up = event.down;
                },
                .down => {
                    self.player.in_down = event.down;
                },
                .left => {
                    self.player.in_left = event.down;
                },
                .right => {
                    self.player.in_right = event.down;
                },
                .shoot => {
                    self.player.in_shoot = event.down;
                },
                .toggle_god_mode => {
                    if (event.down)
                        self.creature.god_mode = !self.creature.god_mode;
                },
                else => {},
            }
        }
    }
}
