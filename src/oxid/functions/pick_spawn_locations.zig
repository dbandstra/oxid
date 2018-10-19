const std = @import("std");
const Math = @import("../../math.zig");
const Gbe = @import("../../gbe.zig");
const GameSession = @import("../game.zig").GameSession;
const GRIDSIZE_SUBPIXELS = @import("../level.zig").GRIDSIZE_SUBPIXELS;
const LEVEL = @import("../level.zig").LEVEL;
const TerrainType = @import("../level.zig").TerrainType;
const C = @import("../components.zig");

const PickSpawnLocations = struct.{
  gridmask: [LEVEL.w * LEVEL.h]bool,

  fn avoidObject(self: *PickSpawnLocations, gs: *GameSession, entity_id: Gbe.EntityId) void {
    if (gs.find(entity_id, C.Transform)) |transform| {
      if (gs.find(entity_id, C.PhysObject)) |phys| {
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
        var gy = gy0; while (gy <= gy1) : (gy += 1) {
          var gx = gx0; while (gx <= gx1) : (gx += 1) {
            self.gridmask[gy * LEVEL.w + gx] = false;
          }
        }
      }
    }
  }

  fn run(gs: *GameSession, out_gridlocs: []Math.Vec2) void {
    var self: PickSpawnLocations = undefined;

    // create a mask over all the grid cells - true means it's ok to spawn here.
    // start by setting true wherever there is a floor
    var gx: u31 = undefined;
    var gy: u31 = undefined;

    gy = 0; while (gy < LEVEL.h) : (gy += 1) {
      gx = 0; while (gx < LEVEL.w) : (gx += 1) {
        const pos = Math.Vec2.{ .x = gx, .y = gy };
        const i = gy * LEVEL.w + gx;
        self.gridmask[i] = LEVEL.getGridTerrainType(pos) == TerrainType.Floor;
      }
    }

    // also, don't spawn anything within 16 screen pixels of a player or
    // monster
    var it = gs.iter(C.Player); while (it.next()) |object| {
      self.avoidObject(gs, object.entity_id);
    }
    var it2 = gs.iter(C.Monster); while (it2.next()) |object| {
      self.avoidObject(gs, object.entity_id);
    }

    // from the gridmask, generate an contiguous array of valid locations
    var candidates: [LEVEL.w * LEVEL.h]Math.Vec2 = undefined;
    var num_candidates: usize = 0;

    gy = 0; while (gy < LEVEL.h) : (gy += 1) {
      gx = 0; while (gx < LEVEL.w) : (gx += 1) {
        if (self.gridmask[gy * LEVEL.w + gx]) {
          candidates[num_candidates] = Math.Vec2.{ .x = gx, .y = gy };
          num_candidates += 1;
        }
      }
    }

    std.debug.assert(num_candidates >= out_gridlocs.len);

    // shuffle the array and copy out as many spawn locations as were requested
    gs.prng.random.shuffle(Math.Vec2, candidates[0..num_candidates]);
    std.mem.copy(Math.Vec2, out_gridlocs, candidates[0..out_gridlocs.len]);
  }
};

// fill given slice with random grid positions, none of which is in a wall,
// near a player, or colocating with another
// TODO - also avoid spawning near pickups
pub const pickSpawnLocations = PickSpawnLocations.run;
