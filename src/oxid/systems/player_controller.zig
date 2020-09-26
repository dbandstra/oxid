const gbe = @import("gbe");
const math = @import("../../common/math.zig");
const game = @import("../game.zig");
const levels = @import("../levels.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

const SystemData = struct {
    id: gbe.EntityId,
    pc: *c.PlayerController,
};

pub fn run(gs: *game.Session) void {
    var it = gs.ecs.iter(SystemData);
    while (it.next()) |self| {
        if (self.pc.respawn_timer > 0) {
            self.pc.respawn_timer -= 1;
            if (self.pc.respawn_timer == 0) {
                spawnPlayer(gs, self);
            }
        }
    }
}

fn spawnPlayer(gs: *game.Session, self: SystemData) void {
    const x = 9 * levels.subpixels_per_tile + levels.subpixels_per_tile / 2;
    const y = 5 * levels.subpixels_per_tile;

    if (p.spawnPlayer(gs, .{
        .player_number = self.pc.player_number,
        .player_controller_id = self.id,
        .pos = math.vec2(x, y),
    })) |player_id| {
        self.pc.player_id = player_id;
    } else |_| {
        // FIXME?
    }
}
