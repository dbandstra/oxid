const u31 = @import("types.zig").u31;
const Direction = @import("math.zig").Direction;
const Vec2 = @import("math.zig").Vec2;
const Velocity = @import("math.zig").Velocity;
const SimpleAnim = @import("graphics.zig").SimpleAnim;
const EntityId = @import("game.zig").EntityId;

pub const Bullet = struct {
  unused: bool, // remove once #1178 is fixed
};

pub const Drawable = struct {
  pub const Type = enum{
    Bullet,
    Soldier,
    SoldierCorpse,
    Monster,
    MonsterSpawn,
    Squid,
    Animation,
  };

  drawType: Type,
  offset: Vec2,
  z_index: u32,
};

pub const Creature = struct {
  invulnerability_timer: u32,
  defaultPhysType: PhysObject.Type,
  hit_points: u32,
  walk_speed: u31,
};

pub const Monster = struct {
  unused: bool, // remove once #1178 is fixed
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
  pub const Type = enum{
    NonSolid,
    Bullet,
    Player,
    Enemy,
  };

  // `physType`: determines whether the object collides with other objects.
  // currently a pretty crappy system.
  physType: Type,

  // `dims`: dimensions of bounding box. origin is at the top-left
  // TODO - replace with separate mins/maxs? (useful for bullet)
  dims: Vec2,

  // `facing`: direction of movement (meaningless if `speed` is 0)
  facing: Direction,

  // `speed`: velocity along the `facing` direction (diagonal motion is not
  // supported). this is measured in subpixels per tick
  // FIXME - shouldn't this be unsigned?
  speed: i32,

  // `push_dir`: if set, the object will try to redirect to go this way if
  // there is no obstruction.
  push_dir: ?Direction,

  // `owner_id`: collision will be skipped between an object and its owner.
  // e.g. a bullet is owned by the person who shot it
  owner_id: EntityId,

  // `damages`: if true, and this object collides with a Creature, the Creature
  // will lose one hit point
  // TODO - remove this. it should be possible to implement it more generically
  // (in the Bullet component)
  damages: bool,

  // `ignore_pits`: if true, this object can travel over pits
  ignore_pits: bool,
};

pub const Player = struct {
  unused: bool, // remove once #1178 is fixed
};

pub const SpawningMonster = struct {
  pub const Type = enum{
    Spider,
    Squid,
  };

  timer: u32,
  monsterType: Type,
};

pub const Transform = struct {
  pos: Vec2,
};

pub const EventCollide = struct {
  self_id: EntityId,
  other_id: EntityId, // 0 = wall
};

pub const EventPlayerDied = struct {
  unused: bool, // remove once #1178 is fixed
};
