const std = @import("std");
const gbe = @import("gbe");
const math = @import("../../common/math.zig");
const GameSession = @import("../game.zig").GameSession;
const levels = @import("../levels.zig");
const c = @import("../components.zig");

const LocalState = struct {
    gridmask: [levels.width * levels.height]bool,
};

const SystemData = struct {
    transform: *const c.Transform,
    phys: *const c.PhysObject,
    creature: ?*const c.Creature,
    web: ?*const c.Web,
    pickup: ?*const c.Pickup,
};

pub const avoidObjectsOfInterest = gbe.buildSystemWithContext(GameSession, SystemData, LocalState, avoidObjectsOfInterestFunc);

fn avoidObjectsOfInterestFunc(gs: *GameSession, ctx: *LocalState, self: SystemData) bool {
    // avoid all creatures (except webs) and pickups
    if (self.web != null) {
        return true;
    }
    const pad = 16 * levels.subpixels_per_pixel;
    const mins_x = self.transform.pos.x + self.phys.entity_bbox.mins.x - pad;
    const mins_y = self.transform.pos.y + self.phys.entity_bbox.mins.y - pad;
    const maxs_x = self.transform.pos.x + self.phys.entity_bbox.maxs.x + pad;
    const maxs_y = self.transform.pos.y + self.phys.entity_bbox.maxs.y + pad;
    const gmins_x = std.math.max(@divFloor(mins_x, levels.subpixels_per_tile), 0);
    const gmins_y = std.math.min(@divFloor(mins_y, levels.subpixels_per_tile), i32(levels.width) - 1);
    const gmaxs_x = std.math.max(@divFloor(maxs_x, levels.subpixels_per_tile), 0);
    const gmaxs_y = std.math.min(@divFloor(maxs_y, levels.subpixels_per_tile), i32(levels.height) - 1);
    const gx0 = @intCast(u31, gmins_x);
    const gy0 = @intCast(u31, gmins_y);
    const gx1 = @intCast(u31, gmaxs_x);
    const gy1 = @intCast(u31, gmaxs_y);
    var gy = gy0; while (gy <= gy1) : (gy += 1) {
        var gx = gx0; while (gx <= gx1) : (gx += 1) {
            ctx.gridmask[gy * levels.width + gx] = false;
        }
    }
    return true;
}

// fill given slice with random grid positions, none of which is in a wall,
// near a player, or colocating with another
pub fn pickSpawnLocations(gs: *GameSession, out_gridlocs: []math.Vec2) void {
    var state: LocalState = undefined;

    // create a mask over all the grid cells - true means it's ok to spawn here.
    // start by setting true wherever there is a floor
    var gx: u31 = undefined;
    var gy: u31 = undefined;

    gy = 0; while (gy < levels.height) : (gy += 1) {
        gx = 0; while (gx < levels.width) : (gx += 1) {
            const pos = math.Vec2.init(gx, gy);
            const i = gy * levels.width + gx;
            state.gridmask[i] = levels.level1.getGridTerrainType(pos) == .Floor;
        }
    }

    // also, don't spawn anything within 16 screen pixels of any "object of
    // interest"
    avoidObjectsOfInterest(gs, &state);

    // from the gridmask, generate an contiguous array of valid locations
    var candidates: [levels.width * levels.height]math.Vec2 = undefined;
    var num_candidates: usize = 0;

    gy = 0; while (gy < levels.height) : (gy += 1) {
        gx = 0; while (gx < levels.width) : (gx += 1) {
            if (state.gridmask[gy * levels.width + gx]) {
                candidates[num_candidates] = math.Vec2.init(gx, gy);
                num_candidates += 1;
            }
        }
    }

    std.debug.assert(num_candidates >= out_gridlocs.len);

    // shuffle the array and copy out as many spawn locations as were requested
    gs.prng.random.shuffle(math.Vec2, candidates[0..num_candidates]);
    std.mem.copy(math.Vec2, out_gridlocs, candidates[0..out_gridlocs.len]);
}
