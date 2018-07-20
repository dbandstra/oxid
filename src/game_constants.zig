// limits

pub const MaxRemovalsPerFrame: usize = 1000;
pub const MaxComponentsPerType: usize = 1000; // FIXME - different for each type

// game

pub const EnemySpeedTicks = 12*60; // every 12 seconds, increase monster speed
pub const MaxEnemySpeedLevel = 4;
pub const PickupSpawnTime = 45*60; // spawn a new pickup every 45 seconds
pub const NextWaveTime = 90; // next wave will begin 1.5 seconds after the last monster dies
pub const MonsterFreezeTimer = 3*60; // monsters freeze for 3 seconds when player dies

// if you push into a wall but there is corner within this distance, move
// around the corner.
pub const PlayerSlipThreshold = 12*16; // FIXME - use screen space

pub const PlayerRespawnTime: u32 = 60; // 1 seconds
pub const PlayerNumLives: u32 = 4; // 1 will be subtracted when drawing the hud

pub const SpiderHitPoints: u32 = 1;
pub const SpiderWalkSpeed: u31 = 8;
pub const SpiderKillPoints: u32 = 10;

pub const SquidHitPoints: u32 = 5;
pub const SquidWalkSpeed: u31 = 6;
pub const SquidKillPoints: u32 = 15;

pub const PickupGetPoints: u32 = 20;

pub const InvulnerabilityTime: u32 = 120; // 2 seconds

pub const PlayerBulletSpeed: u31 = 72;
pub const MonsterBulletSpeed: u31 = 28;

pub const PlayerMaxBullets: usize = 2;
pub const PlayerWalkSpeed1: u31 = 20;
pub const PlayerWalkSpeed2: u31 = 24;
pub const PlayerWalkSpeed3: u31 = 28;

pub const ZIndexSparks: u32 = 120;
pub const ZIndexPlayer: u32 = 100;
pub const ZIndexExplosion: u32 = 81;
pub const ZIndexEnemy: u32 = 80;
pub const ZIndexBullet: u32 = 50;
pub const ZIndexPickup: u32 = 30;
pub const ZIndexCorpse: u32 = 20;

pub const Wave = struct{
  spiders: u32,
  squids: u32,
  speed: u31,
};
pub const Waves = []Wave{
  Wave{ .spiders = 8, .squids = 0, .speed = 0 }, // 1
  Wave{ .spiders = 0, .squids = 8, .speed = 0 }, // 2
  Wave{ .spiders = 12, .squids = 0, .speed = 0 }, // 3
  Wave{ .spiders = 10, .squids = 4, .speed = 0 }, // 4
  Wave{ .spiders = 20, .squids = 0, .speed = 0 }, // 5
  Wave{ .spiders = 0, .squids = 14, .speed = 0 }, // 6
  Wave{ .spiders = 8, .squids = 8, .speed = 1 }, // 7
  Wave{ .spiders = 10, .squids = 10, .speed = 1 }, // 8
  Wave{ .spiders = 15, .squids = 10, .speed = 2 }, // 9
};
