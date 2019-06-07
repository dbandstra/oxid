const gbe = @import("gbe");
const math = @import("../../common/math.zig");
const GameSession = @import("../game.zig").GameSession;
const GRIDSIZE_SUBPIXELS = @import("../level.zig").GRIDSIZE_SUBPIXELS;
const c = @import("../components.zig");
const p = @import("../prototypes.zig");
const util = @import("../util.zig");

const SystemData = struct {
    id: gbe.EntityId,
    pc: *c.PlayerController,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    if (util.decrementTimer(&self.pc.respawn_timer)) {
        spawnPlayer(gs, self);
    }
    return true;
}

fn spawnPlayer(gs: *GameSession, self: SystemData) void {
    if (p.Player.spawn(gs, p.Player.Params {
        .player_controller_id = self.id,
        .pos = math.Vec2.init(
            9 * GRIDSIZE_SUBPIXELS + GRIDSIZE_SUBPIXELS / 2,
            5 * GRIDSIZE_SUBPIXELS,
        ),
    })) |player_id| {
        self.pc.player_id = player_id;
    } else |_| {}
}
