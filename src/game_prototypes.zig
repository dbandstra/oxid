const Direction = @import("math.zig").Direction;
const Vec2 = @import("math.zig").Vec2;
const get_dir_vec = @import("math.zig").get_dir_vec;
const SimpleAnim = @import("graphics.zig").SimpleAnim;
const EntityId = @import("game.zig").EntityId;
const GameSession = @import("game.zig").GameSession;
const GRIDSIZE_PIXELS = @import("game_level.zig").GRIDSIZE_PIXELS;
const GRIDSIZE_SUBPIXELS = @import("game_level.zig").GRIDSIZE_SUBPIXELS;
const Constants = @import("game_constants.zig");
const components = @import("game_components.zig");
const Animation = components.Animation;
const Bullet = components.Bullet;
const Creature = components.Creature;
const Drawable = components.Drawable;
const GameController = components.GameController;
const Monster = components.Monster;
const PhysObject = components.PhysObject;
const Player = components.Player;
const SpawningMonster = components.SpawningMonster;
const Transform = components.Transform;
const EventCollide = components.EventCollide;
const EventPlayerDied = components.EventPlayerDied;
const EventTakeDamage = components.EventTakeDamage;

pub fn spawnGameController(gs: *GameSession) EntityId {
  const entity_id = gs.spawn();

  gs.game_controllers.create(entity_id, GameController{
    .respawn_timer = 0,
    .enemy_speed_level = 0,
    .enemy_speed_ticks = 0,
    .wave_index = 0,
    .next_wave_timer = 90,
  });

  return entity_id;
}

pub fn spawnPlayer(gs: *GameSession, pos: Vec2) EntityId {
  const entity_id = gs.spawn();

  gs.transforms.create(entity_id, Transform{
    .pos = pos,
  });

  gs.phys_objects.create(entity_id, PhysObject{
    .physType = PhysObject.Type.Creature,
    .mins = Vec2.init(0, 0),
    .maxs = Vec2.init(GRIDSIZE_SUBPIXELS - 1, GRIDSIZE_SUBPIXELS - 1),
    .facing = Direction.Right,
    .speed = 0,
    .push_dir = null,
    .owner_id = EntityId{ .id = 0 },
    .ignore_pits = false,
    .internal = undefined,
  });

  gs.drawables.create(entity_id, Drawable{
    .drawType = Drawable.Type.Soldier,
    .z_index = Constants.ZIndexPlayer,
  });

  gs.creatures.create(entity_id, Creature{
    .invulnerability_timer = Constants.InvulnerabilityTime,
    .hit_points = 1,
    .walk_speed = Constants.PlayerWalkSpeed,
  });

  gs.players.create(entity_id, Player{.unused=true});

  return entity_id;
}

pub fn spawnCorpse(gs: *GameSession, pos: Vec2) EntityId {
  const entity_id = gs.spawn();

  gs.transforms.create(entity_id, Transform{
    .pos = pos,
  });

  gs.drawables.create(entity_id, Drawable{
    .drawType = Drawable.Type.SoldierCorpse,
    .z_index = Constants.ZIndexCorpse,
  });

  return entity_id;
}

pub fn spawnSpider(gs: *GameSession, pos: Vec2) EntityId {
  const entity_id = gs.spawn();

  gs.transforms.create(entity_id, Transform{
    .pos = pos,
  });

  gs.phys_objects.create(entity_id, PhysObject{
    .physType = PhysObject.Type.Creature,
    .mins = Vec2.init(0, 0),
    .maxs = Vec2.init(GRIDSIZE_SUBPIXELS - 1, GRIDSIZE_SUBPIXELS - 1),
    .facing = Direction.Right,
    .speed = 0,
    .push_dir = null,
    .owner_id = EntityId{ .id = 0 },
    .ignore_pits = false,
    .internal = undefined,
  });

  gs.drawables.create(entity_id, Drawable{
    .drawType = Drawable.Type.Monster,
    .z_index = Constants.ZIndexEnemy,
  });

  gs.creatures.create(entity_id, Creature{
    .invulnerability_timer = 0,
    .hit_points = Constants.SpiderHitPoints,
    .walk_speed = Constants.SpiderWalkSpeed,
  });

  gs.monsters.create(entity_id, Monster{.unused=true});

  return entity_id;
}

pub fn spawnSquid(gs: *GameSession, pos: Vec2) EntityId {
  const entity_id = gs.spawn();

  gs.transforms.create(entity_id, Transform{
    .pos = pos,
  });

  gs.phys_objects.create(entity_id, PhysObject{
    .physType = PhysObject.Type.Creature,
    .mins = Vec2.init(0, 0),
    .maxs = Vec2.init(GRIDSIZE_SUBPIXELS - 1, GRIDSIZE_SUBPIXELS - 1),
    .facing = Direction.Right,
    .speed = 0,
    .push_dir = null,
    .owner_id = EntityId{ .id = 0 },
    .ignore_pits = false,
    .internal = undefined,
  });

  gs.drawables.create(entity_id, Drawable{
    .drawType = Drawable.Type.Squid,
    .z_index = Constants.ZIndexEnemy,
  });

  gs.creatures.create(entity_id, Creature{
    .invulnerability_timer = 0,
    .hit_points = Constants.SquidHitPoints,
    .walk_speed = Constants.SquidWalkSpeed,
  });

  gs.monsters.create(entity_id, Monster{.unused=true});

  return entity_id;
}

pub fn spawnSpawningMonster(gs: *GameSession, pos: Vec2, monsterType: SpawningMonster.Type) EntityId {
  const entity_id = gs.spawn();

  gs.transforms.create(entity_id, Transform{
    .pos = pos,
  });

  gs.drawables.create(entity_id, Drawable{
    .drawType = Drawable.Type.MonsterSpawn,
    .z_index = Constants.ZIndexEnemy,
  });

  gs.spawning_monsters.create(entity_id, SpawningMonster{
    .timer = 0,
    .monsterType = monsterType,
  });

  return entity_id;
}

pub fn spawnBullet(gs: *GameSession, owner_id: EntityId, pos: Vec2, facing: Direction) EntityId {
  const entity_id = gs.spawn();

  gs.transforms.create(entity_id, Transform{
    .pos = pos,
  });

  const bullet_size = 4 * GRIDSIZE_PIXELS;
  const min = GRIDSIZE_SUBPIXELS / 2 - bullet_size / 2;
  const max = min + bullet_size - 1;

  gs.phys_objects.create(entity_id, PhysObject{
    .physType = PhysObject.Type.Bullet,
    .mins = Vec2.init(min, min),
    .maxs = Vec2.init(max, max),
    .facing = facing,
    .speed = Constants.BulletSpeed,
    .push_dir = null,
    .owner_id = owner_id,
    .ignore_pits = true,
    .internal = undefined,
  });

  gs.drawables.create(entity_id, Drawable{
    .drawType = Drawable.Type.Bullet,
    .z_index = Constants.ZIndexBullet,
  });

  gs.bullets.create(entity_id, Bullet{.unused=true});

  return entity_id;
}

pub fn spawnAnimation(gs: *GameSession, pos: Vec2, simple_anim: SimpleAnim) EntityId {
  const entity_id = gs.spawn();

  gs.transforms.create(entity_id, Transform{
    .pos = pos,
  });

  gs.drawables.create(entity_id, Drawable{
    .drawType = Drawable.Type.Animation,
    .z_index = Constants.ZIndexBullet, // FIXME
  });

  gs.animations.create(entity_id, Animation{
    .simple_anim = simple_anim,
    .frame_index = 0,
    .ticks = 0,
  });

  return entity_id;
}

pub fn spawnEventCollide(gs: *GameSession, self_id: EntityId, other_id: EntityId) EntityId {
  const entity_id = gs.spawn();

  gs.event_collides.create(entity_id, EventCollide{
    .self_id = self_id,
    .other_id = other_id,
  });

  return entity_id;
}

pub fn spawnEventTakeDamage(gs: *GameSession, self_id: EntityId, amount: u32) EntityId {
  const entity_id = gs.spawn();

  gs.event_take_damages.create(entity_id, EventTakeDamage{
    .self_id = self_id,
    .amount = amount,
  });

  return entity_id;
}

pub fn spawnEventPlayerDied(gs: *GameSession) EntityId {
  const entity_id = gs.spawn();

  gs.event_player_dieds.create(entity_id, EventPlayerDied{.unused=true});

  return entity_id;
}
