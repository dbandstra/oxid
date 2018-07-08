const u31 = @import("types.zig").u31;

// limits

pub const MaxRemovalsPerFrame: usize = 1000;
pub const MaxComponentsPerType: usize = 1000; // FIXME - different for each type

// game

// if you push into a wall but there is corner within this distance, move
// around the corner.
pub const PlayerSlipThreshold = 12*16; // FIXME - use screen space

pub const PlayerRespawnTime: u32 = 120; // 2 seconds

pub const SpiderHitPoints: u32 = 1;
pub const SpiderWalkSpeed: u31 = 8;

pub const SquidHitPoints: u32 = 5;
pub const SquidWalkSpeed: u31 = 6;

pub const InvulnerabilityTime: u32 = 120; // 2 seconds

pub const PlayerBulletSpeed: u31 = 48;
pub const MonsterBulletSpeed: u31 = 32;

pub const PlayerMaxBullets: usize = 2;
pub const PlayerWalkSpeed: u31 = 20;

pub const ZIndexSparks: u32 = 120;
pub const ZIndexPlayer: u32 = 100;
pub const ZIndexExplosion: u32 = 81;
pub const ZIndexEnemy: u32 = 80;
pub const ZIndexBullet: u32 = 50;
pub const ZIndexCorpse: u32 = 20;
