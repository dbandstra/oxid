const std = @import("std");
const Math = @import("../common/math.zig");
const gbe = @import("../common/gbe.zig");
const Audio = @import("../audio.zig");
const GameSession = @import("../game.zig").GameSession;
const GRIDSIZE_SUBPIXELS = @import("../level.zig").GRIDSIZE_SUBPIXELS;
const ConstantTypes = @import("../constant_types.zig");
const Constants = @import("../constants.zig");
const C = @import("../components.zig");
const Prototypes = @import("../prototypes.zig");
const pickSpawnLocations = @import("../functions/pick_spawn_locations.zig").pickSpawnLocations;
const GameUtil = @import("../util.zig");

const SystemData = struct{
  gc: *C.GameController,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
  // if all non-persistent monsters are dead, prepare next wave
  if (self.gc.next_wave_timer == 0 and countNonPersistentMonsters(gs) == 0) {
    self.gc.next_wave_timer = Constants.NextWaveTime;
  }
  _ = GameUtil.decrementTimer(&self.gc.wave_message_timer);
  if (GameUtil.decrementTimer(&self.gc.next_wave_timer)) {
    _ = Prototypes.EventSound.spawn(gs, C.EventSound{
      .sample = Audio.Sample.WaveBegin,
    });
    self.gc.wave_number += 1;
    self.gc.wave_message_timer = 180;
    self.gc.enemy_speed_level = 0;
    self.gc.enemy_speed_timer = Constants.EnemySpeedTicks;
    if (self.gc.wave_number - 1 < Constants.Waves.len) {
      const wave = &Constants.Waves[self.gc.wave_number - 1];
      spawnWave(gs, self.gc.wave_number, wave);
      self.gc.enemy_speed_level = wave.speed;
      self.gc.monster_count = countNonPersistentMonsters(gs);
    } else {
      spawnWave(gs, 0, &Constants.DefaultWave);
    }
  }
  if (GameUtil.decrementTimer(&self.gc.enemy_speed_timer)) {
    if (self.gc.enemy_speed_level < Constants.MaxEnemySpeedLevel) {
      self.gc.enemy_speed_level += 1;
      _ = Prototypes.EventSound.spawn(gs, C.EventSound{
        .sample = Audio.Sample.Accelerate,
      });
    }
    self.gc.enemy_speed_timer = Constants.EnemySpeedTicks;
  }
  if (GameUtil.decrementTimer(&self.gc.next_pickup_timer)) {
    const pickup_type =
      if ((gs.getRand().scalar(u32) & 1) == 0)
        ConstantTypes.PickupType.SpeedUp
      else
        ConstantTypes.PickupType.PowerUp;
    spawnPickup(gs, pickup_type);
    self.gc.next_pickup_timer = Constants.PickupSpawnTime;
  }
  _ = GameUtil.decrementTimer(&self.gc.freeze_monsters_timer);
  if (getPlayerScore(gs)) |score| {
    const i  = self.gc.extra_lives_spawned;
    if (i < Constants.ExtraLifeScoreThresholds.len) {
      const threshold = Constants.ExtraLifeScoreThresholds[i];
      if (score >= threshold) {
        spawnPickup(gs, ConstantTypes.PickupType.LifeUp);
        self.gc.extra_lives_spawned += 1;
      }
    }
  }
  return true;
}

fn getPlayerScore(gs: *GameSession) ?u32 {
  // FIXME - what if there is multiplayer?
  var it = gs.iter(C.PlayerController); while (it.next()) |object| {
    return object.data.score;
  }
  return null;
}

fn countNonPersistentMonsters(gs: *GameSession) u32 {
  var count: u32 = 0;
  var it = gs.iter(C.Monster); while (it.next()) |object| {
    if (!object.data.persistent) {
      count += 1;
    }
  }
  return count;
}

fn spawnWave(gs: *GameSession, wave_number: u32, wave: *const ConstantTypes.Wave) void {
  const count = wave.spiders + wave.knights + wave.fastbugs + wave.squids + wave.juggernauts;
  const coins = (wave.spiders + wave.knights) / 3;
  std.debug.assert(count <= 100);
  var spawn_locs_buf: [100]Math.Vec2 = undefined;
  var spawn_locs = spawn_locs_buf[0..count];
  pickSpawnLocations(gs, spawn_locs);
  for (spawn_locs) |loc, i| {
    _ = Prototypes.Monster.spawn(gs, Prototypes.Monster.Params{
      .wave_number = wave_number,
      .pos = Math.Vec2.scale(loc, GRIDSIZE_SUBPIXELS),
      .monster_type =
        if (i < wave.spiders)
          ConstantTypes.MonsterType.Spider
        else if (i < wave.spiders + wave.knights)
          ConstantTypes.MonsterType.Knight
        else if (i < wave.spiders + wave.knights + wave.fastbugs)
          ConstantTypes.MonsterType.FastBug
        else if (i < wave.spiders + wave.knights + wave.fastbugs + wave.squids)
          ConstantTypes.MonsterType.Squid
        else
          ConstantTypes.MonsterType.Juggernaut,
      // TODO - distribute coins randomly across monster types?
      .has_coin = i < coins,
    });
  }
}

fn spawnPickup(gs: *GameSession, pickup_type: ConstantTypes.PickupType) void {
  var spawn_locs: [1]Math.Vec2 = undefined;
  pickSpawnLocations(gs, spawn_locs[0..]);
  const pos = Math.Vec2.scale(spawn_locs[0], GRIDSIZE_SUBPIXELS);
  _ = Prototypes.Pickup.spawn(gs, Prototypes.Pickup.Params{
    .pos = pos,
    .pickup_type = pickup_type,
  });
}
