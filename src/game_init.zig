const std = @import("std");
const Math = @import("math.zig");
const Constants = @import("game_constants.zig");
const GameSession = @import("game.zig").GameSession;
const EntityId = @import("game.zig").EntityId;
const GRIDSIZE_SUBPIXELS = @import("game_level.zig").GRIDSIZE_SUBPIXELS;
const TerrainType = @import("game_level.zig").TerrainType;
const LEVEL = @import("game_level.zig").LEVEL;
const Prototypes = @import("game_prototypes.zig");
const C = @import("game_components.zig");

pub fn game_init(gs: *GameSession) void {
  _ = Prototypes.GameController.spawn(gs);

  const player_controller_id = Prototypes.PlayerController.spawn(gs);

  game_spawn_player(gs, player_controller_id);
}

pub fn game_spawn_player(gs: *GameSession, player_controller_id: EntityId) void {
  _ = Prototypes.Player.spawn(gs, Prototypes.Player.Params{
    .player_controller_id = player_controller_id,
    .pos = Math.Vec2.init(
      9 * GRIDSIZE_SUBPIXELS + GRIDSIZE_SUBPIXELS / 2,
      5 * GRIDSIZE_SUBPIXELS,
    ),
  });
}

pub const MonsterType = enum{
  Spider,
  Squid,
};

pub fn game_spawn_monsters(gs: *GameSession, count: usize, monsterType: MonsterType) void {
  std.debug.assert(count <= 100);
  var spawn_locs: [100]Math.Vec2 = undefined;
  pick_spawn_locations(gs, spawn_locs[0..count]);
  for (spawn_locs[0..count]) |loc| {
    const pos = Math.Vec2.scale(loc, GRIDSIZE_SUBPIXELS);
    switch (monsterType) {
      MonsterType.Spider => {
        _ = Prototypes.Spider.spawn(gs, Prototypes.Spider.Params{
          .pos = pos,
        });
      },
      MonsterType.Squid => {
        _ = Prototypes.Squid.spawn(gs, Prototypes.Squid.Params{
          .pos = pos,
        });
      },
    }
  }
}

pub fn game_spawn_pickup(gs: *GameSession, pickup_type: C.Pickup.Type) void {
  var spawn_locs: [1]Math.Vec2 = undefined;
  pick_spawn_locations(gs, spawn_locs[0..]);
  const pos = Math.Vec2.scale(spawn_locs[0], GRIDSIZE_SUBPIXELS);
  _ = Prototypes.Pickup.spawn(gs, Prototypes.Pickup.Params{
    .pos = pos,
    .pickup_type = pickup_type,
  });
}

// fill given slice with random grid positions, none of which is in a wall and
// none of which are in the same place
fn pick_spawn_locations(gs: *GameSession, out_gridlocs: []Math.Vec2) void {
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
