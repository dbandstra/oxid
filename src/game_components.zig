const Direction = @import("math.zig").Direction;
const Vec2 = @import("math.zig").Vec2;
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
  walk_speed: u32,
};

pub const Monster = struct {
  unused: bool, // remove once #1178 is fixed
};

pub const GameController = struct {
  respawn_timer: u32, // for player
  enemy_speed_level: u32,
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

  physType: Type,
  dims: Vec2,
  facing: Direction,
  speed: i32,
  owner_id: EntityId,
  damages: bool,
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
