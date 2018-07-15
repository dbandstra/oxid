const u31 = @import("types.zig").u31;
const Math = @import("math.zig");
const Velocity = @import("math.zig").Velocity;
const SimpleAnim = @import("graphics.zig").SimpleAnim;
const Constants = @import("game_constants.zig");
const EntityId = @import("game.zig").EntityId;

pub const Bullet = struct {
  unused: bool, // remove once #1178 is fixed
};

pub const Drawable = struct {
  pub const Type = enum{
    PlayerBullet,
    MonsterBullet,
    Soldier,
    SoldierCorpse,
    Spider,
    Squid,
    Animation,
  };

  drawType: Type,
  z_index: u32,
};

pub const Creature = struct {
  invulnerability_timer: u32,
  hit_points: u32,
  walk_speed: u31,
};

pub const Monster = struct {
  const Personality = enum{
    Chase,
    Wander,
  };

  spawning_timer: u32,
  personality: Personality,
  next_shoot_timer: u32,
};

pub const GameController = struct {
  respawn_timer: u32, // for player
  enemy_speed_level: u31,
  enemy_speed_ticks: u32,
  wave_index: u32,
  next_wave_timer: u32,
};

pub const Animation = struct {
  simple_anim: SimpleAnim,
  frame_index: u32,
  ticks: u32,
};

pub const PhysObject = struct {
  pub const FLAG_BULLET: u32 = 1;
  pub const FLAG_MONSTER: u32 = 2;

  // bounding boxes are relative to transform position. the dimensions of the
  // box will be (maxs - mins + 1).
  // `world_bbox`: the bbox used to collide with the level.
  world_bbox: Math.BoundingBox,
  
  // `entity_bbox`: the bbox used to collide with other entities. this may be a
  // bit smaller than the world bbox
  entity_bbox: Math.BoundingBox,

  // `facing`: direction of movement (meaningless if `speed` is 0)
  facing: Math.Direction,

  // `speed`: velocity along the `facing` direction (diagonal motion is not
  // supported). this is measured in subpixels per tick
  // FIXME - shouldn't this be unsigned?
  speed: i32,

  // `push_dir`: if set, the object will try to redirect to go this way if
  // there is no obstruction.
  push_dir: ?Math.Direction,

  // `owner_id`: collision will be skipped between an object and its owner.
  // e.g. a bullet is owned by the person who shot it
  owner_id: EntityId,

  // `ignore_pits`: if true, this object can travel over pits
  ignore_pits: bool,

  // `flags` used with reference to `ignore_flags` (see below)
  flags: u32,

  // `ignore_flags`: skip collision with (i.e., pass through) entities who have
  // any of these flags set in `flags`
  ignore_flags: u32,

  // internal fields used by physics step
  internal: PhysObjectInternal,
};

pub const PhysObjectInternal = struct {
  move_bbox: Math.BoundingBox,
  group_index: usize,
};

pub const Player = struct {
  trigger_released: bool,
  bullets: [Constants.PlayerMaxBullets]?EntityId,
};

pub const Transform = struct {
  pos: Math.Vec2,
};

pub const EventCollide = struct {
  self_id: EntityId,
  other_id: EntityId, // 0 = wall

  // `propelled`: if true, `self` ran into `other` (or they both ran into each
  // other). if false, `other` ran into `self` while `self` was either
  // motionless or moving in another direction.
  propelled: bool,
};

pub const EventPlayerDied = struct {
  unused: bool, // remove once #1178 is fixed
};

pub const EventTakeDamage = struct {
  self_id: EntityId,
  amount: u32,
};
