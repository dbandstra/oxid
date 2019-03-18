const Math = @import("common/math.zig");
const Gbe = @import("common/gbe.zig");
const Graphic = @import("graphics.zig").Graphic;
const SimpleAnim = @import("graphics.zig").SimpleAnim;
const getSimpleAnim = @import("graphics.zig").getSimpleAnim;
const GameSession = @import("game.zig").GameSession;
const GRIDSIZE_PIXELS = @import("level.zig").GRIDSIZE_PIXELS;
const GRIDSIZE_SUBPIXELS = @import("level.zig").GRIDSIZE_SUBPIXELS;
const ConstantTypes = @import("constant_types.zig");
const Constants = @import("constants.zig");
const C = @import("components.zig");

fn make_bbox(diameter: u31) Math.BoundingBox {
  const graphic_diameter = GRIDSIZE_SUBPIXELS;
  const min = graphic_diameter / 2 - diameter / 2;
  const max = graphic_diameter / 2 + diameter / 2 - 1;
  return Math.BoundingBox{
    .mins = Math.Vec2.init(min, min),
    .maxs = Math.Vec2.init(max, max),
  };
}

// all entities are full size for colliding with the level
const world_bbox = make_bbox(GRIDSIZE_SUBPIXELS);
// player's ent-vs-ent bbox is 50% size
const player_entity_bbox = make_bbox(GRIDSIZE_SUBPIXELS / 2);
// monster's ent-vs-ent bbox is 75% size
const monster_entity_bbox = make_bbox(GRIDSIZE_SUBPIXELS * 3 / 4);
// pickups are 75% size
const pickup_entity_bbox = make_bbox(GRIDSIZE_SUBPIXELS * 3 / 4);

pub const bullet_bbox = blk: {
  const bullet_size = 4 * GRIDSIZE_PIXELS;
  const min = GRIDSIZE_SUBPIXELS / 2 - bullet_size / 2;
  const max = min + bullet_size - 1;
  break :blk Math.BoundingBox{
    .mins = Math.Vec2.init(min, min),
    .maxs = Math.Vec2.init(max, max),
  };
};

pub const MainController = struct{
  pub const Params = struct{
    high_score: u32,
  };

  pub fn spawn(gs: *GameSession, params: Params) !Gbe.EntityId {
    const entity_id = gs.spawn();
    errdefer gs.undoSpawn(entity_id);

    try gs.addComponent(entity_id, C.MainController{
      .high_score = params.high_score,
      .new_high_score = false,
      .game_running_state = null,
    });

    return entity_id;
  }
};

pub const GameController = struct{
  pub fn spawn(gs: *GameSession) !Gbe.EntityId {
    const entity_id = gs.spawn();
    errdefer gs.undoSpawn(entity_id);

    try gs.addComponent(entity_id, C.GameController{
      .game_over = false,
      .monster_count = 0,
      .enemy_speed_level = 0,
      .enemy_speed_timer = Constants.EnemySpeedTicks,
      .wave_number = 0,
      .next_wave_timer = 90,
      .next_pickup_timer = 15*60,
      .freeze_monsters_timer = 0,
      .extra_lives_spawned = 0,
      .wave_message_timer = 0,
    });

    return entity_id;
  }
};

pub const PlayerController = struct{
  pub fn spawn(gs: *GameSession) !Gbe.EntityId {
    const entity_id = gs.spawn();
    errdefer gs.undoSpawn(entity_id);

    try gs.addComponent(entity_id, C.PlayerController{
      .player_id = null,
      .lives = Constants.PlayerNumLives,
      .score = 0,
      .respawn_timer = 1,
    });

    return entity_id;
  }
};

pub const Player = struct{
  pub const Params = struct{
    player_controller_id: Gbe.EntityId,
    pos: Math.Vec2,
  };

  pub fn spawn(gs: *GameSession, params: Params) !Gbe.EntityId {
    const entity_id = gs.spawn();
    errdefer gs.undoSpawn(entity_id);

    try gs.addComponent(entity_id, C.Transform{
      .pos = Math.Vec2.init(params.pos.x, params.pos.y + GRIDSIZE_SUBPIXELS),
    });

    try gs.addComponent(entity_id, C.PhysObject{
      .illusory = true, // illusory during invulnerability stage
      .world_bbox = world_bbox,
      .entity_bbox = player_entity_bbox,
      .facing = Math.Direction.E,
      .speed = 0,
      .push_dir = null,
      .owner_id = Gbe.EntityId{ .id = 0 },
      .ignore_pits = false,
      .flags = 0,
      .ignore_flags = 0,
      .internal = undefined,
    });

    try gs.addComponent(entity_id, C.Creature{
      .invulnerability_timer = Constants.InvulnerabilityTime,
      .hit_points = 1,
      .flinch_timer = 0,
      .god_mode = false,
    });

    try gs.addComponent(entity_id, C.Player{
      .player_controller_id = params.player_controller_id,
      .trigger_released = true,
      .bullets = []?Gbe.EntityId{null} ** Constants.PlayerMaxBullets,
      .attack_level = C.Player.AttackLevel.One,
      .speed_level = C.Player.SpeedLevel.One,
      .spawn_anim_y_remaining = GRIDSIZE_SUBPIXELS, // will animate upwards 1 tile upon spawning
      .dying_timer = 0,
      .last_pickup = null,
      .line_of_fire = null,
      .in_left = false,
      .in_right = false,
      .in_up = false,
      .in_down = false,
      .in_shoot = false,
    });

    return entity_id;
  }
};

pub const PlayerCorpse = struct{
  pub const Params = struct{
    pos: Math.Vec2,
  };

  pub fn spawn(gs: *GameSession, params: Params) !Gbe.EntityId {
    const entity_id = gs.spawn();
    errdefer gs.undoSpawn(entity_id);

    try gs.addComponent(entity_id, C.Transform{
      .pos = params.pos,
    });

    try gs.addComponent(entity_id, C.SimpleGraphic{
      .graphic = Graphic.ManDying6,
      .z_index = Constants.ZIndexCorpse,
      .directional = false,
    });

    return entity_id;
  }
};

pub const Monster = struct{
  pub const Params = struct{
    wave_number: u32,
    monster_type: ConstantTypes.MonsterType,
    pos: Math.Vec2,
    has_coin: bool,
  };

  pub fn spawn(gs: *GameSession, params: Params) !Gbe.EntityId {
    const monster_values = Constants.getMonsterValues(params.monster_type);

    const entity_id = gs.spawn();
    errdefer gs.undoSpawn(entity_id);

    try gs.addComponent(entity_id, C.Transform{
      .pos = params.pos,
    });

    try gs.addComponent(entity_id, C.PhysObject{
      .illusory = false,
      .world_bbox = world_bbox,
      .entity_bbox = monster_entity_bbox,
      .facing = Math.Direction.E,
      .speed = 0,
      .push_dir = null,
      .owner_id = Gbe.EntityId{ .id = 0 },
      .ignore_pits = false,
      .flags = C.PhysObject.FLAG_MONSTER,
      .ignore_flags = 0,
      .internal = undefined,
    });

    try gs.addComponent(entity_id, C.Creature{
      .invulnerability_timer = 0,
      .hit_points = 999, // invulnerable while spawning
      .flinch_timer = 0,
      .god_mode = false,
    });

    const can_shoot =
      if (monster_values.first_shooting_level) |first_level|
        params.wave_number >= first_level
      else
        false;

    try gs.addComponent(entity_id, C.Monster{
      .monster_type = params.monster_type,
      .spawning_timer = Constants.MonsterSpawnTime,
      .full_hit_points = monster_values.hit_points,
      .personality =
        if (params.monster_type == ConstantTypes.MonsterType.Juggernaut)
          C.Monster.Personality.Chase
        else
          switch (gs.getRand().range(u32, 0, 2)) {
            0 => C.Monster.Personality.Chase,
            else => C.Monster.Personality.Wander,
          },
      .kill_points = monster_values.kill_points,
      .can_shoot = can_shoot,
      .can_drop_webs = monster_values.can_drop_webs,
      .next_attack_timer =
        if (can_shoot or monster_values.can_drop_webs)
          gs.getRand().range(u32, 75, 400)
        else
          0,
      .has_coin = params.has_coin,
      .persistent = monster_values.persistent,
    });

    return entity_id;
  }
};

pub const Web = struct{
  pub const Params = struct{
    pos: Math.Vec2,
  };

  pub fn spawn(gs: *GameSession, params: Params) !Gbe.EntityId {
    const entity_id = gs.spawn();
    errdefer gs.undoSpawn(entity_id);

    try gs.addComponent(entity_id, C.Transform{
      .pos = params.pos,
    });

    try gs.addComponent(entity_id, C.PhysObject{
      .illusory = true,
      .world_bbox = world_bbox,
      .entity_bbox = monster_entity_bbox,
      .facing = Math.Direction.E,
      .speed = 0,
      .push_dir = null,
      .owner_id = Gbe.EntityId{ .id = 0 },
      .ignore_pits = false,
      .flags = C.PhysObject.FLAG_WEB,
      .ignore_flags = 0,
      .internal = undefined,
    });

    try gs.addComponent(entity_id, C.Web{});

    try gs.addComponent(entity_id, C.Creature{
      .invulnerability_timer = 0,
      .hit_points = 3,
      .flinch_timer = 0,
      .god_mode = false,
    });

    return entity_id;
  }
};

pub const Bullet = struct{
  pub const BulletType = enum{
    MonsterBullet,
    PlayerBullet,
  };

  pub const Params = struct{
    inflictor_player_controller_id: ?Gbe.EntityId,
    owner_id: Gbe.EntityId,
    pos: Math.Vec2,
    facing: Math.Direction,
    bullet_type: BulletType,
    cluster_size: u32,
  };

  pub fn spawn(gs: *GameSession, params: Params) !Gbe.EntityId {
    const entity_id = gs.spawn();
    errdefer gs.undoSpawn(entity_id);

    try gs.addComponent(entity_id, C.Transform{
      .pos = params.pos,
    });

    try gs.addComponent(entity_id, C.PhysObject{
      .illusory = true,
      .world_bbox = bullet_bbox,
      .entity_bbox = bullet_bbox,
      .facing = params.facing,
      .speed = switch (params.bullet_type) {
        BulletType.MonsterBullet => Constants.MonsterBulletSpeed,
        BulletType.PlayerBullet => Constants.PlayerBulletSpeed,
      },
      .push_dir = null,
      .owner_id = params.owner_id,
      .ignore_pits = true,
      .flags = C.PhysObject.FLAG_BULLET,
      .ignore_flags = C.PhysObject.FLAG_BULLET | switch (params.bullet_type) {
        // monster bullets ignore all monsters and webs
        BulletType.MonsterBullet => C.PhysObject.FLAG_MONSTER | C.PhysObject.FLAG_WEB,
        // player bullets ignore only the player that shot it (via `owner_id`)
        BulletType.PlayerBullet => 0,
      },
      .internal = undefined,
    });

    try gs.addComponent(entity_id, C.Bullet{
      .inflictor_player_controller_id = params.inflictor_player_controller_id,
      .damage = params.cluster_size,
      .line_of_fire = null,
    });

    try gs.addComponent(entity_id, C.SimpleGraphic{
      .graphic = switch (params.bullet_type) {
        BulletType.MonsterBullet => Graphic.MonBullet,
        BulletType.PlayerBullet => switch (params.cluster_size) {
          1 => Graphic.PlaBullet,
          2 => Graphic.PlaBullet2,
          else => Graphic.PlaBullet3,
        },
      },
      .z_index = Constants.ZIndexBullet,
      .directional = true,
    });

    return entity_id;
  }
};

pub const Animation = struct{
  pub const Params = struct{
    pos: Math.Vec2,
    simple_anim: SimpleAnim,
    z_index: u32,
  };

  pub fn spawn(gs: *GameSession, params: Params) !Gbe.EntityId {
    const entity_id = gs.spawn();
    errdefer gs.undoSpawn(entity_id);

    try gs.addComponent(entity_id, C.Transform{
      .pos = params.pos,
    });

    try gs.addComponent(entity_id, C.Animation{
      .simple_anim = params.simple_anim,
      .frame_index = 0,
      .frame_timer = getSimpleAnim(params.simple_anim).ticks_per_frame,
      .z_index = params.z_index,
    });

    return entity_id;
  }
};

pub const Pickup = struct{
  pub const Params = struct{
    pos: Math.Vec2,
    pickup_type: ConstantTypes.PickupType,
  };

  pub fn spawn(gs: *GameSession, params: Params) !Gbe.EntityId {
    const pickup_values = Constants.getPickupValues(params.pickup_type);

    const entity_id = gs.spawn();
    errdefer gs.undoSpawn(entity_id);

    try gs.addComponent(entity_id, C.Transform{
      .pos = params.pos,
    });

    try gs.addComponent(entity_id, C.SimpleGraphic{
      .graphic = switch (params.pickup_type) {
        ConstantTypes.PickupType.PowerUp => Graphic.PowerUp,
        ConstantTypes.PickupType.SpeedUp => Graphic.SpeedUp,
        ConstantTypes.PickupType.LifeUp => Graphic.LifeUp,
        ConstantTypes.PickupType.Coin => Graphic.Coin,
      },
      .z_index = Constants.ZIndexPickup,
      .directional = false,
    });

    try gs.addComponent(entity_id, C.PhysObject{
      .illusory = true,
      .world_bbox = world_bbox,
      .entity_bbox = pickup_entity_bbox,
      .facing = Math.Direction.E,
      .speed = 0,
      .push_dir = null,
      .owner_id = Gbe.EntityId{ .id = 0 },
      .ignore_pits = false,
      .flags = 0,
      .ignore_flags = C.PhysObject.FLAG_BULLET | C.PhysObject.FLAG_MONSTER,
      .internal = undefined,
    });

    try gs.addComponent(entity_id, C.Pickup{
      .pickup_type = params.pickup_type,
      .timer = pickup_values.lifetime,
      .get_points = pickup_values.get_points,
    });

    return entity_id;
  }
};

fn Event(comptime T: type) type {
  return struct{
    pub fn spawn(gs: *GameSession, body: T) !Gbe.EntityId {
      const entity_id = gs.spawn();
      errdefer gs.undoSpawn(entity_id);

      try gs.addComponent(entity_id, body);

      return entity_id;
    }
  };
}

pub const EventAwardLife = Event(C.EventAwardLife);
pub const EventAwardPoints = Event(C.EventAwardPoints);
pub const EventCollide = Event(C.EventCollide);
pub const EventConferBonus = Event(C.EventConferBonus);
pub const EventDraw = Event(C.EventDraw);
pub const EventDrawBox = Event(C.EventDrawBox);
pub const EventInput = Event(C.EventInput);
pub const EventMonsterDied = Event(C.EventMonsterDied);
pub const EventPlayerDied = Event(C.EventPlayerDied);
pub const EventPlayerOutOfLives = Event(C.EventPlayerOutOfLives);
pub const EventPostScore = Event(C.EventPostScore);
pub const EventQuit = Event(C.EventQuit);
pub const EventSaveHighScore = Event(C.EventSaveHighScore);
pub const EventSound = Event(C.EventSound);
pub const EventTakeDamage = Event(C.EventTakeDamage);
