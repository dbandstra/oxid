const std = @import("std");
const Vec2 = @import("math.zig").Vec2;
const Constants = @import("game_constants.zig");
const GameSession = @import("game.zig").GameSession;
const GRIDSIZE_SUBPIXELS = @import("game_level.zig").GRIDSIZE_SUBPIXELS;
const TerrainType = @import("game_level.zig").TerrainType;
const LEVEL = @import("game_level.zig").LEVEL;
const SpawningMonster = @import("game_components.zig").SpawningMonster;
const Prototypes = @import("game_prototypes.zig");

pub fn game_init(gs: *GameSession) void {
  _ = Prototypes.spawnGameController(gs);

  game_spawn_player(gs);
  // game_spawn_more(gs);
}

pub fn game_spawn_player(gs: *GameSession) void {
  _ = Prototypes.spawnPlayer(gs, Vec2{
    .x = 9 * GRIDSIZE_SUBPIXELS + GRIDSIZE_SUBPIXELS / 2,
    .y = 5 * GRIDSIZE_SUBPIXELS,
  });
}

pub fn game_spawn_monsters(gs: *GameSession, count: usize, monsterType: SpawningMonster.Type) void {
  std.debug.assert(count <= 100);
  var spawn_locs: [100]Vec2 = undefined;
  pick_spawn_locations(gs, spawn_locs[0..count]);
  for (spawn_locs[0..count]) |loc| {
    _ = Prototypes.spawnSpawningMonster(gs, Vec2.scale(loc, GRIDSIZE_SUBPIXELS), monsterType);
  }
}

// fill given slice with random grid positions, none of which is in a wall and
// none of which are in the same place
fn pick_spawn_locations(gs: *GameSession, out_gridlocs: []Vec2) void {
  var i: usize = 0;

  while (i < out_gridlocs.len) : (i += 1) {
    const out_loc = &out_gridlocs[i];

    var inf0: usize = 0;
    while (true) {
      if (inf0 >= 10000) {
        unreachable;
      }
      inf0 += 1;

      out_loc.x = gs.getRand().range(i32, 0, @intCast(i32, LEVEL.w));
      out_loc.y = gs.getRand().range(i32, 0, @intCast(i32, LEVEL.h));

      if (LEVEL.get_grid_terrain_type(out_loc.*) != TerrainType.Floor) {
        continue;
      }

      var j: usize = 0;
      while (j < i) : (j += 1) {
        if (out_gridlocs[j].x == out_loc.x and out_gridlocs[j].y == out_loc.y) {
          break;
        }
      }
      if (j < i) {
        continue;
      }

      break;
    }
  }
}
