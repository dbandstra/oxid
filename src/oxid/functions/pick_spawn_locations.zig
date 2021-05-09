const std = @import("std");
const gbe = @import("gbe");
const math = @import("../../common/math.zig");
const game = @import("../game.zig");
const levels = @import("../levels.zig");
const c = @import("../components.zig");

// fill given slice with random grid positions, none of which is in a wall,
// near a player, or colocating with another.
// the length of `gridlocs_buf` specifies the number of requested spawn
// locations. fewer may be returned if all available spots are occupied
pub fn pickSpawnLocations(gs: *game.Session, gridlocs_buf: []math.Vec2) []const math.Vec2 {
    var gridmask: [levels.width * levels.height]bool = undefined;

    // create a mask over all the grid cells - true means it's ok to spawn here.
    // start by setting true wherever there is a floor
    var gx: u31 = undefined;
    var gy: u31 = undefined;

    gy = 0;
    while (gy < levels.height) : (gy += 1) {
        gx = 0;
        while (gx < levels.width) : (gx += 1) {
            const in_wall = blk: {
                const tile = levels.getMapTile(levels.level1, gx, gy) orelse break :blk true;
                break :blk tile.terrain_type == .wall;
            };
            gridmask[gy * levels.width + gx] = !in_wall;
        }
    }

    // also, don't spawn anything within 16 screen pixels of any "object of
    // interest"
    var it = gs.ecs.iter(struct {
        transform: *const c.Transform,
        phys: *const c.PhysObject,
        creature: ?*const c.Creature,
        web: ?*const c.Web,
        pickup: ?*const c.Pickup,
    });
    while (it.next()) |entry| {
        // avoid all creatures (except webs) and pickups
        if (entry.web != null) continue;
        const pad = 16 * levels.subpixels_per_pixel;
        const mins_x = entry.transform.pos.x + entry.phys.entity_bbox.mins.x - pad;
        const mins_y = entry.transform.pos.y + entry.phys.entity_bbox.mins.y - pad;
        const maxs_x = entry.transform.pos.x + entry.phys.entity_bbox.maxs.x + pad;
        const maxs_y = entry.transform.pos.y + entry.phys.entity_bbox.maxs.y + pad;
        const gmins_x = std.math.max(@divFloor(mins_x, levels.subpixels_per_tile), 0);
        const gmins_y = std.math.max(@divFloor(mins_y, levels.subpixels_per_tile), 0);
        const gmaxs_x = std.math.min(@divFloor(maxs_x, levels.subpixels_per_tile), @as(i32, levels.width) - 1);
        const gmaxs_y = std.math.min(@divFloor(maxs_y, levels.subpixels_per_tile), @as(i32, levels.height) - 1);
        const gx0 = @intCast(u31, gmins_x);
        const gy0 = @intCast(u31, gmins_y);
        const gx1 = @intCast(u31, gmaxs_x);
        const gy1 = @intCast(u31, gmaxs_y);
        gy = gy0;
        while (gy <= gy1) : (gy += 1) {
            gx = gx0;
            while (gx <= gx1) : (gx += 1) {
                gridmask[gy * levels.width + gx] = false;
            }
        }
    }

    // from the gridmask, make a list of all valid locations
    var candidates: [levels.width * levels.height]math.Vec2 = undefined;
    var num_candidates: usize = 0;

    gy = 0;
    while (gy < levels.height) : (gy += 1) {
        gx = 0;
        while (gx < levels.width) : (gx += 1) {
            if (gridmask[gy * levels.width + gx]) {
                candidates[num_candidates] = math.vec2(gx, gy);
                num_candidates += 1;
            }
        }
    }

    // shuffle the list
    gs.prng.random.shuffle(math.Vec2, candidates[0..num_candidates]);

    // copy out as many spawn locations as were requested
    const count = std.math.min(gridlocs_buf.len, num_candidates);
    std.mem.copy(math.Vec2, gridlocs_buf[0..count], candidates[0..count]);
    return gridlocs_buf[0..count];
}

// get a single spawn location
pub fn pickSpawnLocation(gs: *game.Session) ?math.Vec2 {
    var buf: [1]math.Vec2 = undefined;
    const locs = pickSpawnLocations(gs, &buf);
    if (locs.len == 0) return null;
    return locs[0];
}
