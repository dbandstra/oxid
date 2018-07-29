const Math = @import("../math.zig");
const Gbe = @import("../gbe.zig");
const Constants = @import("constants.zig");
const SimpleAnim = @import("graphics.zig").SimpleAnim;

pub const Bullet = struct {
  inflictor_player_controller_id: ?Gbe.EntityId,
  damage: u32,
};

pub const Drawable = struct {
  pub const Type = enum{
    PlayerBullet,
    PlayerBullet2,
    PlayerBullet3,
    MonsterBullet,
    Soldier,
    SoldierCorpse,
    Spider,
    Squid,
    Animation,
    Pickup,
  };

  draw_type: Type,
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
  full_hit_points: u32,
  personality: Personality,
  kill_points: u32,
  next_shoot_timer: u32,
};

pub const GameController = struct {
  monster_count: u32,
  enemy_speed_level: u31,
  enemy_speed_timer: u32,
  wave_index: u32,
  next_wave_timer: u32,
  next_pickup_timer: u32,
  freeze_monsters_timer: u32,
};

pub const PlayerController = struct {
  lives: u32,
  score: u32,
  respawn_timer: u32,
};

pub const Animation = struct {
  simple_anim: SimpleAnim,
  frame_index: u32,
  frame_timer: u32,
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
  owner_id: Gbe.EntityId,

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

pub const Pickup = struct {
  const Type = enum{
    PowerUp,
    SpeedUp,
    LifeUp,
  };

  pickup_type: Type,
  timer: u32,
};

pub const Player = struct {
  const AttackLevel = enum {
    One,
    Two,
    Three,
  };

  const SpeedLevel = enum {
    One,
    Two,
    Three,
  };

  player_controller_id: Gbe.EntityId,
  trigger_released: bool,
  bullets: [Constants.PlayerMaxBullets]?Gbe.EntityId,
  attack_level: AttackLevel,
  speed_level: SpeedLevel,
  dying_timer: u32,
};

pub const Transform = struct {
  pos: Math.Vec2,
};

pub const EventCollide = struct {
  self_id: Gbe.EntityId,
  other_id: Gbe.EntityId, // 0 = wall

  // `propelled`: if true, `self` ran into `other` (or they both ran into each
  // other). if false, `other` ran into `self` while `self` was either
  // motionless or moving in another direction.
  propelled: bool,
};

pub const EventConferBonus = struct {
  recipient_id: Gbe.EntityId,
  pickup_type: Pickup.Type,
};

pub const EventAwardLife = struct {
  player_controller_id: Gbe.EntityId,
};

pub const EventAwardPoints = struct {
  player_controller_id: Gbe.EntityId,
  points: u32,
};

pub const EventMonsterDied = struct {
  unused: u32, // FIXME
};

pub const EventPlayerDied = struct {
  player_controller_id: Gbe.EntityId,
};

pub const EventTakeDamage = struct {
  inflictor_player_controller_id: ?Gbe.EntityId,
  self_id: Gbe.EntityId,
  amount: u32,
};
