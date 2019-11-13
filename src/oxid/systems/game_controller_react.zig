const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const Constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

const SystemData = struct{
    gc: *c.GameController,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) gbe.ThinkResult {
    if (gs.findFirst(c.EventPlayerDied) != null) {
        self.gc.freeze_monsters_timer = Constants.monster_freeze_time;
    }
    var it = gs.iter(c.EventPlayerOutOfLives); while (it.next()) |object| {
        if (self.gc.num_players_remaining > 0) {
            self.gc.num_players_remaining -= 1;
            if (self.gc.num_players_remaining == 0) {
                _ = p.EventGameOver.spawn(gs, .{}) catch undefined;
            }
        }
    }
    var it2 = gs.iter(c.EventMonsterDied); while (it2.next()) |_| {
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
    var it3 = gs.iter(c.EventShowMessage); while (it3.next()) |object| {
        self.gc.wave_message = object.data.message;
        self.gc.wave_message_timer = Constants.duration60(180);
    }
    return .Remain;
}
