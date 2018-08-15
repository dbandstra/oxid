const std = @import("std");
const Math = @import("../../math.zig");
const GameSession = @import("../game.zig").GameSession;
const GRIDSIZE_SUBPIXELS = @import("../level.zig").GRIDSIZE_SUBPIXELS;
const LEVEL = @import("../level.zig").LEVEL;
const TerrainType = @import("../level.zig").TerrainType;
const C = @import("../components.zig");

// fill given slice with random grid positions, none of which is in a wall,
// near a player, or colocating with another
// TODO - also avoid spawning near pickups
pub fn pickSpawnLocations(gs: *GameSession, out_gridlocs: []Math.Vec2) void {
  // create a mask over all the grid cells - true means it's ok to spawn here.
  // start by setting true wherever there is a floor
  var gridmask: [LEVEL.w * LEVEL.h]bool = undefined;
  var gx: u31 = undefined;
  var gy: u31 = undefined;

  gy = 0; while (gy < LEVEL.h) : (gy += 1) {
    gx = 0; while (gx < LEVEL.w) : (gx += 1) {
      const pos = Math.Vec2{ .x = gx, .y = gy };
      const i = gy * LEVEL.w + gx;
      gridmask[i] = LEVEL.getGridTerrainType(pos) == TerrainType.Floor;
    }
  }

  // also, don't spawn anything within 16 screen pixels of a player
  var it = gs.gbe.iter(C.Player); while (it.next()) |object| {
    if (gs.gbe.find(object.entity_id, C.Transform)) |transform| {
      if (gs.gbe.find(object.entity_id, C.PhysObject)) |phys| {
        const pad = 16 * Math.SUBPIXELS;
        const mins_x = transform.pos.x + phys.entity_bbox.mins.x - pad;
        const mins_y = transform.pos.y + phys.entity_bbox.mins.y - pad;
        const maxs_x = transform.pos.x + phys.entity_bbox.maxs.x + pad;
        const maxs_y = transform.pos.y + phys.entity_bbox.maxs.y + pad;
        var gmins_x = @divFloor(mins_x, GRIDSIZE_SUBPIXELS);
        var gmins_y = @divFloor(mins_y, GRIDSIZE_SUBPIXELS);
        var gmaxs_x = @divFloor(maxs_x, GRIDSIZE_SUBPIXELS);
        var gmaxs_y = @divFloor(maxs_y, GRIDSIZE_SUBPIXELS);
        if (gmins_x < 0) gmins_x = 0;
        if (gmins_y < 0) gmins_y = 0;
        if (gmaxs_x > i32(LEVEL.w) - 1) gmaxs_x = i32(LEVEL.w) - 1;
        if (gmaxs_y > i32(LEVEL.h) - 1) gmaxs_y = i32(LEVEL.h) - 1;
        const gx0 = @intCast(u31, gmins_x);
        const gy0 = @intCast(u31, gmins_y);
        const gx1 = @intCast(u31, gmaxs_x);
        const gy1 = @intCast(u31, gmaxs_y);
        gy = gy0; while (gy <= gy1) : (gy += 1) {
          gx = gx0; while (gx <= gx1) : (gx += 1) {
            gridmask[gy * LEVEL.w + gx] = false;
          }
        }
      }
    }
  }

  // from the gridmask, generate an contiguous array of valid locations
  var candidates: [LEVEL.w * LEVEL.h]Math.Vec2 = undefined;
  var num_candidates: usize = 0;

  gy = 0; while (gy < LEVEL.h) : (gy += 1) {
    gx = 0; while (gx < LEVEL.w) : (gx += 1) {
      if (gridmask[gy * LEVEL.w + gx]) {
        candidates[num_candidates] = Math.Vec2{ .x = gx, .y = gy };
        num_candidates += 1;
      }
    }
  }

  std.debug.assert(num_candidates >= out_gridlocs.len);

  // shuffle the array and copy out as many spawn locations as were requested
  gs.gbe.prng.random.shuffle(Math.Vec2, candidates[0..num_candidates]);
  std.mem.copy(Math.Vec2, out_gridlocs, candidates[0..out_gridlocs.len]);
}
