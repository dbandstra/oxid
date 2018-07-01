const u31 = @IntType(false, 31);

// limits

pub const MaxRemovalsPerFrame: usize = 1000;
pub const MaxComponentsPerType: usize = 1000; // FIXME - different for each type

// game

pub const PlayerRespawnTime: u32 = 120; // 2 seconds

pub const SpiderHitPoints: u32 = 1;
pub const SpiderWalkSpeed: u31 = 8;

pub const SquidHitPoints: u32 = 5;
pub const SquidWalkSpeed: u31 = 6;

// pub const EnemiesPerSpawn: usize = 8;

pub const InvulnerabilityTime: u32 = 120; // 2 seconds

pub const BulletSpeed: i32 = 48;

pub const PlayerWalkSpeed: u31 = 20;

pub const ZIndexPlayer: u32 = 100;
pub const ZIndexBullet: u32 = 90;
pub const ZIndexEnemy: u32 = 80;
pub const ZIndexCorpse: u32 = 20;
