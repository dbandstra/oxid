const std = @import("std");
const gbe = @import("gbe");
const math = @import("../../common/math.zig");
const GameSession = @import("../game.zig").GameSession;
const levels = @import("../levels.zig");
const c = @import("../components.zig");

const PickSpawnLocations = struct {
    gridmask: [levels.W * levels.H]bool,

    fn avoidObject(self: *PickSpawnLocations, gs: *GameSession, entity_id: gbe.EntityId) void {
        if (gs.find(entity_id, c.Transform)) |transform| {
            if (gs.find(entity_id, c.PhysObject)) |phys| {
                const pad = 16 * levels.SUBPIXELS_PER_PIXEL;
                const mins_x = transform.pos.x + phys.entity_bbox.mins.x - pad;
                const mins_y = transform.pos.y + phys.entity_bbox.mins.y - pad;
                const maxs_x = transform.pos.x + phys.entity_bbox.maxs.x + pad;
                const maxs_y = transform.pos.y + phys.entity_bbox.maxs.y + pad;
                const gmins_x = std.math.max(@divFloor(mins_x, levels.SUBPIXELS_PER_TILE), 0);
                const gmins_y = std.math.min(@divFloor(mins_y, levels.SUBPIXELS_PER_TILE), i32(levels.W) - 1);
                const gmaxs_x = std.math.max(@divFloor(maxs_x, levels.SUBPIXELS_PER_TILE), 0);
                const gmaxs_y = std.math.min(@divFloor(maxs_y, levels.SUBPIXELS_PER_TILE), i32(levels.H) - 1);
                const gx0 = @intCast(u31, gmins_x);
                const gy0 = @intCast(u31, gmins_y);
                const gx1 = @intCast(u31, gmaxs_x);
                const gy1 = @intCast(u31, gmaxs_y);
                var gy = gy0; while (gy <= gy1) : (gy += 1) {
                    var gx = gx0; while (gx <= gx1) : (gx += 1) {
                        self.gridmask[gy * levels.W + gx] = false;
                    }
                }
            }
        }
    }

    fn run(gs: *GameSession, out_gridlocs: []math.Vec2) void {
        var self: PickSpawnLocations = undefined;

        // create a mask over all the grid cells - true means it's ok to spawn here.
        // start by setting true wherever there is a floor
        var gx: u31 = undefined;
        var gy: u31 = undefined;

        gy = 0; while (gy < levels.H) : (gy += 1) {
            gx = 0; while (gx < levels.W) : (gx += 1) {
                const pos = math.Vec2.init(gx, gy);
                const i = gy * levels.W + gx;
                self.gridmask[i] = levels.LEVEL1.getGridTerrainType(pos) == levels.TerrainType.Floor;
            }
        }

        // also, don't spawn anything within 16 screen pixels of a player or
        // monster
        var it = gs.iter(c.Player); while (it.next()) |object| {
            self.avoidObject(gs, object.entity_id);
        }
        var it2 = gs.iter(c.Monster); while (it2.next()) |object| {
            self.avoidObject(gs, object.entity_id);
        }

        // from the gridmask, generate an contiguous array of valid locations
        var candidates: [levels.W * levels.H]math.Vec2 = undefined;
        var num_candidates: usize = 0;

        gy = 0; while (gy < levels.H) : (gy += 1) {
            gx = 0; while (gx < levels.W) : (gx += 1) {
                if (self.gridmask[gy * levels.W + gx]) {
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
};

// fill given slice with random grid positions, none of which is in a wall,
// near a player, or colocating with another
// TODO - also avoid spawning near pickups
pub const pickSpawnLocations = PickSpawnLocations.run;
