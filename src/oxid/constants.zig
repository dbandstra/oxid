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
    MonsterType.Spider => MonsterValues.{
      .hit_points = 1,
      .move_speed = [4]u31.{ 6, 9, 12, 15 },
      .kill_points = 10,
      .first_shooting_level = null,
      .can_drop_webs = false,
      .persistent = false,
    },
    MonsterType.Knight => MonsterValues.{
      .hit_points = 2,
      .move_speed = [4]u31.{ 6, 9, 12, 15 },
      .kill_points = 20,
      .first_shooting_level = 9,
      .can_drop_webs = false,
      .persistent = false,
    },
    MonsterType.FastBug => MonsterValues.{
      .hit_points = 1,
      .move_speed = [4]u31.{ 12, 16, 20, 24 },
      .kill_points = 10,
      .first_shooting_level = null,
      .can_drop_webs = false,
      .persistent = false,
    },
    MonsterType.Squid => MonsterValues.{
      .hit_points = 5,
      .move_speed = [4]u31.{ 3, 4, 6, 8 },
      .kill_points = 80,
      .first_shooting_level = null,
      .can_drop_webs = true,
      .persistent = false,
    },
    MonsterType.Juggernaut => MonsterValues.{
      .hit_points = 9999,
      .move_speed = [4]u31.{ 4, 4, 4, 4 },
      .kill_points = 0,
      .first_shooting_level = null,
      .can_drop_webs = false,
      .persistent = true,
    },
  };
}

pub fn getPickupValues(pickup_type: PickupType) PickupValues {
  return switch (pickup_type) {
    PickupType.Coin => PickupValues.{
      .lifetime = 6*60,
      .get_points = 20,
    },
    PickupType.LifeUp => PickupValues.{
      .lifetime = 15*60,
      .get_points = 0,
    },
    PickupType.PowerUp,
    PickupType.SpeedUp => PickupValues.{
      .lifetime = 12*60,
      .get_points = 0,
    },
  };
}

pub const InvulnerabilityTime: u32 = 2*60;

pub const PlayerBulletSpeed: u31 = 64;
pub const MonsterBulletSpeed: u31 = 20;

pub const PlayerMaxBullets: usize = 2;
pub const PlayerMoveSpeed = [3]u31.{ 16, 20, 24 };

pub const ZIndexSparks: u32 = 120;
pub const ZIndexPlayer: u32 = 100;
pub const ZIndexExplosion: u32 = 81;
pub const ZIndexEnemy: u32 = 80;
pub const ZIndexBullet: u32 = 50;
pub const ZIndexPickup: u32 = 30;
pub const ZIndexWeb: u32 = 25;
pub const ZIndexCorpse: u32 = 20;

// these values need testing
pub const ExtraLifeScoreThresholds = []u32.{
  1500,
  3000,
  6000,
};

pub const Waves = []Wave.{
  Wave.{ .spiders = 6, .knights = 0, .fastbugs = 0, .squids = 0, .juggernauts = 0, .speed = 0, .message = "GET READY!" }, // 1
  Wave.{ .spiders = 6, .knights = 2, .fastbugs = 0, .squids = 0, .juggernauts = 0, .speed = 0, .message = null }, // 2
  Wave.{ .spiders = 8, .knights = 4, .fastbugs = 0, .squids = 0, .juggernauts = 0, .speed = 0, .message = null }, // 3
  Wave.{ .spiders = 6, .knights = 0, .fastbugs = 0, .squids = 2, .juggernauts = 0, .speed = 0, .message = "TANK SQUIDS" }, // 4
  Wave.{ .spiders = 6, .knights = 4, .fastbugs = 0, .squids = 0, .juggernauts = 0, .speed = 0, .message = null }, // 5
  Wave.{ .spiders = 0, .knights = 0, .fastbugs = 6, .squids = 0, .juggernauts = 0, .speed = 0, .message = null }, // 6
  Wave.{ .spiders = 8, .knights = 6, .fastbugs = 0, .squids = 2, .juggernauts = 0, .speed = 1, .message = null }, // 7
  Wave.{ .spiders = 0, .knights = 5, .fastbugs = 8, .squids = 0, .juggernauts = 0, .speed = 0, .message = null }, // 8
  Wave.{ .spiders = 0, .knights = 6, .fastbugs = 0, .squids = 0, .juggernauts = 0, .speed = 1, .message = "FIRE BUGS" }, // 9
  Wave.{ .spiders = 4, .knights = 6, .fastbugs = 0, .squids = 0, .juggernauts = 0, .speed = 1, .message = null }, // 10
  Wave.{ .spiders = 7, .knights = 0, .fastbugs = 0, .squids = 0, .juggernauts = 1, .speed = 2, .message = "DREADNAUT!" }, // 11
  Wave.{ .spiders = 7, .knights = 2, .fastbugs = 0, .squids = 0, .juggernauts = 0, .speed = 2, .message = null }, // 12
  Wave.{ .spiders = 8, .knights = 5, .fastbugs = 0, .squids = 0, .juggernauts = 0, .speed = 2, .message = null }, // 13
  Wave.{ .spiders = 6, .knights = 1, .fastbugs = 0, .squids = 2, .juggernauts = 0, .speed = 2, .message = null }, // 14
  Wave.{ .spiders = 7, .knights = 4, .fastbugs = 0, .squids = 0, .juggernauts = 0, .speed = 2, .message = null }, // 15
  Wave.{ .spiders = 0, .knights = 0, .fastbugs = 7, .squids = 0, .juggernauts = 0, .speed = 2, .message = null }, // 16
  Wave.{ .spiders = 8, .knights = 6, .fastbugs = 0, .squids = 2, .juggernauts = 0, .speed = 2, .message = null }, // 17
  Wave.{ .spiders = 0, .knights = 6, .fastbugs = 9, .squids = 0, .juggernauts = 0, .speed = 2, .message = null }, // 18
};

// this is used after you pass the final wave. FIXME - do something better
pub const DefaultWave = Wave.{ .spiders = 1, .knights = 0, .fastbugs = 0, .squids = 0, .juggernauts = 0, .speed = 0, .message = null };
