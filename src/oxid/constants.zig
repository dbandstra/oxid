const ConstantTypes = @import("constant_types.zig");
const MonsterType = ConstantTypes.MonsterType;
const MonsterValues = ConstantTypes.MonsterValues;
const PickupType = ConstantTypes.PickupType;
const PickupValues = ConstantTypes.PickupValues;
const Wave = ConstantTypes.Wave;

pub const EnemySpeedTicks = 12*60; // every 12 seconds, increase monster speed
pub const MaxEnemySpeedLevel = 4;
pub const PickupSpawnTime = 45*60; // spawn a new pickup every 45 seconds
pub const NextWaveTime = 30; // next wave will begin 0.5 seconds after the last monster dies
pub const MonsterFreezeTimer = 3*60; // monsters freeze for 3 seconds when player dies

// if you push into a wall but there is corner within this distance, move
// around the corner.
pub const PlayerSlipThreshold = 12*16; // FIXME - use screen space

pub const PlayerRespawnTime: u32 = 60; // 1 second
pub const PlayerNumLives: u32 = 4; // 1 will be subtracted when drawing the hud

pub fn getMonsterValues(monster_type: MonsterType) MonsterValues {
  return switch (monster_type) {
    MonsterType.Spider => MonsterValues{
      .hit_points = 1,
      .move_speed = 8,
      .kill_points = 10,
      .can_shoot = true,
    },
    MonsterType.FastBug => MonsterValues{
      .hit_points = 1,
      .move_speed = 16,
      .kill_points = 10,
      .can_shoot = false,
    },
    MonsterType.Squid => MonsterValues{
      .hit_points = 5,
      .move_speed = 6,
      .kill_points = 15,
      .can_shoot = true,
    },
  };
}

pub fn getPickupValues(pickup_type: PickupType) PickupValues {
  return switch (pickup_type) {
    PickupType.Coin => PickupValues{
      .lifetime = 6*60,
      .get_points = 20,
    },
    PickupType.LifeUp => PickupValues{
      .lifetime = 10*60,
      .get_points = 0,
    },
    PickupType.PowerUp,
    PickupType.SpeedUp => PickupValues{
      .lifetime = 8*60,
      .get_points = 0,
    },
  };
}

pub const InvulnerabilityTime: u32 = 2*60;

pub const PlayerBulletSpeed: u31 = 72;
pub const MonsterBulletSpeed: u31 = 28;

pub const PlayerMaxBullets: usize = 2;
pub const PlayerMoveSpeed1: u31 = 20;
pub const PlayerMoveSpeed2: u31 = 24;
pub const PlayerMoveSpeed3: u31 = 28;

pub const ZIndexSparks: u32 = 120;
pub const ZIndexPlayer: u32 = 100;
pub const ZIndexExplosion: u32 = 81;
pub const ZIndexEnemy: u32 = 80;
pub const ZIndexBullet: u32 = 50;
pub const ZIndexPickup: u32 = 30;
pub const ZIndexCorpse: u32 = 20;

// these values need testing
pub const ExtraLifeScoreThresholds = []u32{
  1000,
  3000,
  6000,
};

pub const Waves = []Wave{
  Wave{ .spiders = 8, .fastbugs = 0, .squids = 0, .speed = 0, .coins = 3 }, // 1
  Wave{ .spiders = 0, .fastbugs = 0, .squids = 6, .speed = 0, .coins = 0 }, // 2
  Wave{ .spiders = 12, .fastbugs = 0, .squids = 0, .speed = 0, .coins = 4 }, // 3
  Wave{ .spiders = 0, .fastbugs = 8, .squids = 0, .speed = 0, .coins = 2 }, // 4
  Wave{ .spiders = 10, .fastbugs = 4, .squids = 0, .speed = 0, .coins = 3 }, // 5
  Wave{ .spiders = 20, .fastbugs = 0, .squids = 0, .speed = 0, .coins = 6 }, // 6
  Wave{ .spiders = 0, .fastbugs = 6, .squids = 6, .speed = 0, .coins = 2 }, // 7
  Wave{ .spiders = 4, .fastbugs = 10, .squids = 0, .speed = 1, .coins = 2 }, // 8
  Wave{ .spiders = 10, .fastbugs = 4, .squids = 10, .speed = 1, .coins = 5 }, // 9
  Wave{ .spiders = 15, .fastbugs = 4, .squids = 10, .speed = 2, .coins = 8 }, // 10
};

// this is used after you pass the final wave. FIXME - do something better
pub const DefaultWave = Wave{ .spiders = 1, .fastbugs = 0, .squids = 0, .speed = 0, .coins = 0 };
