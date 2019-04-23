const Math = @import("common/math.zig");
const Draw = @import("common/draw.zig");
const Gbe = @import("common/gbe.zig");
const ConstantTypes = @import("constant_types.zig");
const Constants = @import("constants.zig");
const Audio = @import("audio.zig");
const SimpleAnim = @import("graphics.zig").SimpleAnim;
const Graphic = @import("graphics.zig").Graphic;
const input = @import("input.zig");

pub const MainController = struct{
  pub const GameRunningState = struct{
    render_move_boxes: bool,
    exit_dialog_open: bool,
  };

  high_score: u32,
  new_high_score: bool,
  game_running_state: ?GameRunningState,
};

pub const Bullet = struct{
  inflictor_player_controller_id: ?Gbe.EntityId,
  damage: u32,
  line_of_fire: ?Math.BoundingBox,
};

pub const Creature = struct{
  invulnerability_timer: u32,
  hit_points: u32,
  flinch_timer: u32,
  god_mode: bool,
};

pub const Monster = struct{
  pub const Personality = enum{
    Chase,
    Wander,
  };

  monster_type: ConstantTypes.MonsterType,
  spawning_timer: u32,
  full_hit_points: u32,
  personality: Personality,
  kill_points: u32,
  can_shoot: bool,
  can_drop_webs: bool,
  next_attack_timer: u32,
  has_coin: bool,
  persistent: bool,
};

pub const Web = struct{};

pub const GameController = struct{
  game_over: bool,
  monster_count: u32,
  enemy_speed_level: u31,
  enemy_speed_timer: u32,
  wave_number: u32,
  next_wave_timer: u32,
  next_pickup_timer: u32,
  freeze_monsters_timer: u32,
  extra_lives_spawned: u32,
  wave_message: ?[]const u8,
  wave_message_timer: u32,
};

pub const PlayerController = struct{
  player_id: ?Gbe.EntityId,
  lives: u32,
  score: u32,
  respawn_timer: u32,
};

pub const Animation = struct{
  simple_anim: SimpleAnim,
  frame_index: u32,
  frame_timer: u32,
  z_index: u32,
};

pub const SimpleGraphic = struct{
  graphic: Graphic,
  z_index: u32,
  directional: bool,
};

pub const PhysObject = struct{
  pub const FLAG_BULLET: u32 = 1;
  pub const FLAG_MONSTER: u32 = 2;
  pub const FLAG_WEB: u32 = 4;

  // `illusory`: if true, this object is non-solid, but still causes 'collide'
  // events when overlapped
  illusory: bool,

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

pub const PhysObjectInternal = struct{
  move_bbox: Math.BoundingBox,
  group_index: usize,
};

pub const Pickup = struct{
  pickup_type: ConstantTypes.PickupType,
  timer: u32,
  get_points: u32,
};

pub const Player = struct{
  pub const AttackLevel = enum{
    One,
    Two,
    Three,
  };

  pub const SpeedLevel = enum{
    One,
    Two,
    Three,
  };

  player_controller_id: Gbe.EntityId,
  trigger_released: bool,
  bullets: [Constants.PlayerMaxBullets]?Gbe.EntityId,
  attack_level: AttackLevel,
  speed_level: SpeedLevel,
  spawn_anim_y_remaining: u31,
  dying_timer: u32,
  last_pickup: ?ConstantTypes.PickupType,
  line_of_fire: ?Math.BoundingBox,
  in_left: bool,
  in_right: bool,
  in_up: bool,
  in_down: bool,
  in_shoot: bool,
};

pub const Transform = struct{
  pos: Math.Vec2,
};

pub const EventAwardLife = struct{
  player_controller_id: Gbe.EntityId,
};

pub const EventAwardPoints = struct{
  player_controller_id: Gbe.EntityId,
  points: u32,
};

pub const EventCollide = struct{
  self_id: Gbe.EntityId,
  other_id: Gbe.EntityId, // 0 = wall

  // `propelled`: if true, `self` ran into `other` (or they both ran into each
  // other). if false, `other` ran into `self` while `self` was either
  // motionless or moving in another direction.
  propelled: bool,
};

pub const EventConferBonus = struct{
  recipient_id: Gbe.EntityId,
  pickup_type: ConstantTypes.PickupType,
};

pub const EventDraw = struct{
  pos: Math.Vec2,
  graphic: Graphic,
  transform: Draw.Transform,
  z_index: u32,
};

pub const EventDrawBox = struct{
  box: Math.BoundingBox,
  color: Draw.Color,
};

pub const EventInput = struct{
  command: input.Command,
  down: bool,
};

pub const EventMonsterDied = struct{};

pub const EventPlayerDied = struct{
  player_controller_id: Gbe.EntityId,
};

pub const EventPlayerOutOfLives = struct{
  player_controller_id: Gbe.EntityId,
};

pub const EventPostScore = struct{
  score: u32,
};

pub const EventQuit = struct{};

pub const EventSaveHighScore = struct{
  high_score: u32,
};

pub const EventSound = struct{
  sample: Audio.Sample,
};

pub const EventTakeDamage = struct{
  inflictor_player_controller_id: ?Gbe.EntityId,
  self_id: Gbe.EntityId,
  amount: u32,
};
