const game = @import("../game.zig");
const constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

const SystemData = struct {
    gc: *c.GameController,
};

pub fn run(gs: *game.Session) void {
    var it = gs.ecs.iter(SystemData);
    while (it.next()) |self| {
        think(gs, self);
    }
}

fn think(gs: *game.Session, self: SystemData) void {
    if (gs.ecs.findFirstComponent(c.EventPlayerDied) != null) {
        self.gc.freeze_monsters_timer = constants.monster_freeze_time;
    }
    var it = gs.ecs.componentIter(c.EventPlayerOutOfLives);
    while (it.next() != null) {
        if (self.gc.num_players_remaining > 0) {
            self.gc.num_players_remaining -= 1;
            if (self.gc.num_players_remaining == 0) {
                _ = p.EventGameOver.spawn(gs, .{}) catch undefined;
            }
        }
    }
    var it2 = gs.ecs.componentIter(c.EventMonsterDied);
    while (it2.next() != null) {
        if (self.gc.monster_count > 0) {
            self.gc.monster_count -= 1;
            if (self.gc.monster_count == 4 and self.gc.enemy_speed_level < 1) {
                self.gc.enemy_speed_timer = 1;
            }
            if (self.gc.monster_count == 3 and self.gc.enemy_speed_level < 2) {
                self.gc.enemy_speed_timer = 1;
            }
            if (self.gc.monster_count == 2 and self.gc.enemy_speed_level < 3) {
                self.gc.enemy_speed_timer = 1;
            }
            if (self.gc.monster_count == 1 and self.gc.enemy_speed_level < 4) {
                self.gc.enemy_speed_timer = 1;
            }
        }
    }
    var it3 = gs.ecs.componentIter(c.EventShowMessage);
    while (it3.next()) |event| {
        self.gc.wave_message = event.message;
        self.gc.wave_message_timer = constants.duration60(180);
    }
}
