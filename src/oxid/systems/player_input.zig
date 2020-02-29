const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");

pub fn run(gs: *GameSession) void {
    var it = gs.ecs.iter(struct {
        player: *c.Player,
        creature: *c.Creature,
        inbox: gbe.Inbox(16, c.EventGameInput, null),
    });
    while (it.next()) |self| {
        for (self.inbox.all()) |event| {
            // TODO is it possible to have the event point right to the player id?
            if (event.player_number != self.player.player_number) {
                continue;
            }
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
                    if (event.down) {
                        self.creature.god_mode = !self.creature.god_mode;
                    }
                },
                else => {},
            }
        }
    }
}
