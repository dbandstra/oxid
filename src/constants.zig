const ConstantTypes = @import("constant_types.zig");
const MonsterType = ConstantTypes.MonsterType;
const MonsterValues = ConstantTypes.MonsterValues;
const PickupType = ConstantTypes.PickupType;
const PickupValues = ConstantTypes.PickupValues;
const Wave = ConstantTypes.Wave;

pub const EnemySpeedTicks = 20*60; // every 20 seconds, increase monster speed
pub const MaxEnemySpeedLevel = 4;
pub const PickupSpawnTime = 60*60; // spawn a new pickup every 60 seconds
pub const NextWaveTime = 45; // next wave will begin 0.75 seconds after the last monster dies
pub const MonsterSpawnTime = 90; // monsters are in spawning state for 1.5 seconds
pub const MonsterFreezeTime = 4*60; // monsters freeze for 3 seconds when player dies

// if you push into a wall but there is corner within this distance, move
// around the corner.
pub const PlayerSlipThreshold = 12*16; // FIXME - use screen space

pub const PlayerDeathAnimTime: u32 = 90; // 1.5 seconds
pub const PlayerRespawnTime: u32 = 150; // 2.5 seconds
pub const PlayerNumLives: u32 = 3;

pub fn getMonsterValues(monster_type: MonsterType) MonsterValues {
  return switch (monster_type) {
    MonsterType.Spider => MonsterValues{
      .hit_points = 1,
      .move_speed = [4]u31{ 6, 9, 12, 15 },
      .kill_points = 10,
      .first_shooting_level = null,
      .can_drop_webs = false,
      .persistent = false,
    },
    MonsterType.Knight => MonsterValues{
      .hit_points = 2,
      .move_speed = [4]u31{ 6, 9, 12, 15 },
      .kill_points = 20,
      .first_shooting_level = 9,
      .can_drop_webs = false,
      .persistent = false,
    },
    MonsterType.FastBug => MonsterValues{
      .hit_points = 1,
      .move_speed = [4]u31{ 12, 16, 20, 24 },
      .kill_points = 10,
      .first_shooting_level = null,
      .can_drop_webs = false,
      .persistent = false,
    },
    MonsterType.Squid => MonsterValues{
      .hit_points = 5,
      .move_speed = [4]u31{ 3, 4, 6, 8 },
      .kill_points = 80,
      .first_shooting_level = null,
      .can_drop_webs = true,
      .persistent = false,
    },
    MonsterType.Juggernaut => MonsterValues{
      .hit_points = 9999,
      .move_speed = [4]u31{ 4, 4, 4, 4 },
      .kill_points = 0,
      .first_shooting_level = null,
      .can_drop_webs = false,
      .persistent = true,
    },
  };
}

pub fn getPickupValues(pickup_type: PickupType) PickupValues {
  return switch (pickup_type) {
    PickupType.Coin => PickupValues{
      .lifetime = 6*60,
      .get_points = 20,
      .message = null,
    },
    PickupType.LifeUp => PickupValues{
      .lifetime = 15*60,
      .get_points = 0,
      .message = "Life up!",
    },
    PickupType.PowerUp => PickupValues{
      .lifetime = 12*60,
      .get_points = 0,
      .message = "Power up!",
    },
    PickupType.SpeedUp => PickupValues{
      .lifetime = 12*60,
      .get_points = 0,
      .message = "Speed up!",
    },
  };
}

pub const InvulnerabilityTime: u32 = 2*60;

pub const PlayerBulletSpeed: u31 = 64;
pub const MonsterBulletSpeed: u31 = 20;

pub const PlayerMaxBullets: usize = 2;
pub const PlayerMoveSpeed = [3]u31{ 16, 20, 24 };

pub const ZIndexSparks: u32 = 120;
pub const ZIndexPlayer: u32 = 100;
pub const ZIndexExplosion: u32 = 81;
pub const ZIndexEnemy: u32 = 80;
pub const ZIndexBullet: u32 = 50;
pub const ZIndexPickup: u32 = 30;
pub const ZIndexWeb: u32 = 25;
pub const ZIndexCorpse: u32 = 20;

pub const ExtraLifeScoreThresholds = []u32{
  1500,
  3000,
  6000,
  10000,
  15000,
  20000,
  25000,
};
