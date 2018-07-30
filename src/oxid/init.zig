const std = @import("std");
const Math = @import("../math.zig");
const Gbe = @import("../gbe.zig");
const ConstantTypes = @import("constant_types.zig");
const GameSession = @import("game.zig").GameSession;
const GRIDSIZE_SUBPIXELS = @import("level.zig").GRIDSIZE_SUBPIXELS;
const TerrainType = @import("level.zig").TerrainType;
const LEVEL = @import("level.zig").LEVEL;
const Prototypes = @import("prototypes.zig");
const C = @import("components.zig");

pub fn gameInit(gs: *GameSession) void {
  _ = Prototypes.GameController.spawn(gs);

  const player_controller_id = Prototypes.PlayerController.spawn(gs) catch unreachable;

  spawnPlayer(gs, player_controller_id);
}

pub fn spawnPlayer(gs: *GameSession, player_controller_id: Gbe.EntityId) void {
  _ = Prototypes.Player.spawn(gs, Prototypes.Player.Params{
    .player_controller_id = player_controller_id,
    .pos = Math.Vec2.init(
      9 * GRIDSIZE_SUBPIXELS + GRIDSIZE_SUBPIXELS / 2,
      5 * GRIDSIZE_SUBPIXELS,
    ),
  });
}

pub fn spawnWave(gs: *GameSession, wave: *const ConstantTypes.Wave) void {
  const count = wave.spiders + wave.fastbugs + wave.squids;
  std.debug.assert(count <= 100);
  var spawn_locs_buf: [100]Math.Vec2 = undefined;
  var spawn_locs = spawn_locs_buf[0..count];
  pickSpawnLocations(gs, spawn_locs);
  for (spawn_locs) |loc, i| {
    _ = Prototypes.Monster.spawn(gs, Prototypes.Monster.Params{
      .pos = Math.Vec2.scale(loc, GRIDSIZE_SUBPIXELS),
      .monster_type =
        if (i < wave.spiders)
          ConstantTypes.MonsterType.Spider
        else if (i < wave.spiders + wave.fastbugs)
          ConstantTypes.MonsterType.FastBug
        else
          ConstantTypes.MonsterType.Squid,
      // TODO - distribute coins randomly across monster types?
      .has_coin = i < wave.coins,
    });
  }
}

// this is a cheat
pub fn killAllMonsters(gs: *GameSession) void {
  var num_monsters: usize = 0;
  var it = gs.gbe.iter(C.Monster); while (it.next()) |object| {
    num_monsters += 1;
  }

  if (num_monsters > 0) {
    it = gs.gbe.iter(C.Monster); while (it.next()) |object| {
      gs.gbe.markEntityForRemoval(object.entity_id);
    }
    gs.gbe.applyRemovals();
  }

  if (gs.gbe.iter(C.GameController).next()) |object| {
    object.data.next_wave_timer = 1;
  }
}

pub fn spawnPickup(gs: *GameSession, pickup_type: C.Pickup.Type) void {
  var spawn_locs: [1]Math.Vec2 = undefined;
  pickSpawnLocations(gs, spawn_locs[0..]);
  const pos = Math.Vec2.scale(spawn_locs[0], GRIDSIZE_SUBPIXELS);
  _ = Prototypes.Pickup.spawn(gs, Prototypes.Pickup.Params{
    .pos = pos,
    .pickup_type = pickup_type,
  });
}

// fill given slice with random grid positions, none of which is in a wall,
// near a player, or colocating with another
// TODO - also avoid spawning near pickups
fn pickSpawnLocations(gs: *GameSession, out_gridlocs: []Math.Vec2) void {
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
