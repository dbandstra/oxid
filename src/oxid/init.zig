const std = @import("std");
const Math = @import("../math.zig");
const Gbe = @import("../gbe.zig");
const Constants = @import("constants.zig");
const GameSession = @import("game.zig").GameSession;
const GRIDSIZE_SUBPIXELS = @import("level.zig").GRIDSIZE_SUBPIXELS;
const TerrainType = @import("level.zig").TerrainType;
const LEVEL = @import("level.zig").LEVEL;
const Prototypes = @import("prototypes.zig");
const C = @import("components.zig");

pub fn gameInit(gs: *GameSession) void {
  _ = Prototypes.GameController.spawn(gs);

  const player_controller_id = Prototypes.PlayerController.spawn(gs);

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

pub const MonsterType = enum{
  Spider,
  Squid,
};

pub fn spawnMonsters(gs: *GameSession, count: usize, monsterType: MonsterType) void {
  std.debug.assert(count <= 100);
  var spawn_locs: [100]Math.Vec2 = undefined;
  pickSpawnLocations(gs, spawn_locs[0..count]);
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

pub fn spawnPickup(gs: *GameSession, pickup_type: C.Pickup.Type) void {
  var spawn_locs: [1]Math.Vec2 = undefined;
  pickSpawnLocations(gs, spawn_locs[0..]);
  const pos = Math.Vec2.scale(spawn_locs[0], GRIDSIZE_SUBPIXELS);
  _ = Prototypes.Pickup.spawn(gs, Prototypes.Pickup.Params{
    .pos = pos,
    .pickup_type = pickup_type,
  });
}

// fill given slice with random grid positions, none of which is in a wall and
// none of which are in the same place
fn pickSpawnLocations(gs: *GameSession, out_gridlocs: []Math.Vec2) void {
  var i: usize = 0;

  while (i < out_gridlocs.len) : (i += 1) {
    const out_loc = &out_gridlocs[i];

    var inf0: usize = 0;
    while (true) {
      if (inf0 >= 10000) {
        unreachable;
      }
      inf0 += 1;

      out_loc.x = gs.gbe.getRand().range(i32, 0, @intCast(i32, LEVEL.w));
      out_loc.y = gs.gbe.getRand().range(i32, 0, @intCast(i32, LEVEL.h));

      if (LEVEL.getGridTerrainType(out_loc.*) != TerrainType.Floor) {
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
