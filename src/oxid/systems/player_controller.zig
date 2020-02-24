const gbe = @import("gbe");
const math = @import("../../common/math.zig");
const GameSession = @import("../game.zig").GameSession;
const levels = @import("../levels.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");
const util = @import("../util.zig");

const SystemData = struct {
    id: gbe.EntityId,
    pc: *c.PlayerController,
};

pub fn run(gs: *GameSession) void {
    var it = gs.ecs.iter(SystemData);

    while (it.next()) |self| {
        if (util.decrementTimer(&self.pc.respawn_timer)) {
            spawnPlayer(gs, self);
        }
    }
}

fn spawnPlayer(gs: *GameSession, self: SystemData) void {
    if (p.Player.spawn(gs, .{
        .player_number = self.pc.player_number,
        .player_controller_id = self.id,
        .pos = math.Vec2.init(
            9 * levels.subpixels_per_tile + levels.subpixels_per_tile / 2,
            5 * levels.subpixels_per_tile,
        ),
    })) |player_id| {
        self.pc.player_id = player_id;
    } else |_| {
        // FIXME?
    }
}
