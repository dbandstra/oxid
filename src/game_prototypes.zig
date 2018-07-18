const Math = @import("math.zig");
const SimpleAnim = @import("graphics.zig").SimpleAnim;
const EntityId = @import("game.zig").EntityId;
const GameSession = @import("game.zig").GameSession;
const GRIDSIZE_PIXELS = @import("game_level.zig").GRIDSIZE_PIXELS;
const GRIDSIZE_SUBPIXELS = @import("game_level.zig").GRIDSIZE_SUBPIXELS;
const Constants = @import("game_constants.zig");
const C = @import("game_components.zig");

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
// pickups are 50% size
const pickup_entity_bbox = make_bbox(GRIDSIZE_SUBPIXELS / 2);

pub const GameController = struct{
  pub fn spawn(gs: *GameSession) EntityId {
    const entity_id = gs.spawn();

    gs.game_controllers.create(entity_id, C.GameController{
      .enemy_speed_level = 0,
      .enemy_speed_ticks = 0,
      .wave_index = 0,
      .next_wave_timer = 90,
      .next_pickup_timer = 15*60,
    });

    return entity_id;
  }
};

pub const PlayerController = struct{
  pub fn spawn(gs: *GameSession) EntityId {
    const entity_id = gs.spawn();

    gs.player_controllers.create(entity_id, C.PlayerController{
      .lives = Constants.PlayerNumLives,
      .score = 0,
      .respawn_timer = 0,
    });

    return entity_id;
  }
};

pub const Player = struct{
  pub const Params = struct{
    player_controller_id: EntityId,
    pos: Math.Vec2,
  };

  pub fn spawn(gs: *GameSession, params: Params) EntityId {
    const entity_id = gs.spawn();

    gs.transforms.create(entity_id, C.Transform{
      .pos = params.pos,
    });

    gs.phys_objects.create(entity_id, C.PhysObject{
      .world_bbox = world_bbox,
      .entity_bbox = player_entity_bbox,
      .facing = Math.Direction.E,
      .speed = 0,
      .push_dir = null,
      .owner_id = EntityId{ .id = 0 },
      .ignore_pits = false,
      .flags = 0,
      .ignore_flags = 0,
      .internal = undefined,
    });

    gs.drawables.create(entity_id, C.Drawable{
      .drawType = C.Drawable.Type.Soldier,
      .z_index = Constants.ZIndexPlayer,
    });

    gs.creatures.create(entity_id, C.Creature{
      .invulnerability_timer = Constants.InvulnerabilityTime,
      .hit_points = 1,
      .walk_speed = Constants.PlayerWalkSpeed1,
    });

    gs.players.create(entity_id, C.Player{
      .player_controller_id = params.player_controller_id,
      .trigger_released = true,
      .bullets = []?EntityId{null} ** Constants.PlayerMaxBullets,
      .attack_level = C.Player.AttackLevel.One,
      .speed_level = C.Player.SpeedLevel.One,
    });

    return entity_id;
  }
};

pub const Corpse = struct{
  pub const Params = struct{
    pos: Math.Vec2,
  };

  pub fn spawn(gs: *GameSession, params: Params) EntityId {
    const entity_id = gs.spawn();

    gs.transforms.create(entity_id, C.Transform{
      .pos = params.pos,
    });

    gs.drawables.create(entity_id, C.Drawable{
      .drawType = C.Drawable.Type.SoldierCorpse,
      .z_index = Constants.ZIndexCorpse,
    });

    return entity_id;
  }
};

pub const Spider = struct{
  pub const Params = struct{
    pos: Math.Vec2,
  };

  pub fn spawn(gs: *GameSession, params: Params) EntityId {
    const entity_id = gs.spawn();

    gs.transforms.create(entity_id, C.Transform{
      .pos = params.pos,
    });

    gs.phys_objects.create(entity_id, C.PhysObject{
      .world_bbox = world_bbox,
      .entity_bbox = monster_entity_bbox,
      .facing = Math.Direction.E,
      .speed = 0,
      .push_dir = null,
      .owner_id = EntityId{ .id = 0 },
      .ignore_pits = false,
      .flags = C.PhysObject.FLAG_MONSTER,
      .ignore_flags = 0,
      .internal = undefined,
    });

    gs.drawables.create(entity_id, C.Drawable{
      .drawType = C.Drawable.Type.Spider,
      .z_index = Constants.ZIndexEnemy,
    });

    gs.creatures.create(entity_id, C.Creature{
      .invulnerability_timer = 0,
      .hit_points = 1,
      .walk_speed = Constants.SpiderWalkSpeed,
    });

    gs.monsters.create(entity_id, C.Monster{
      .spawning_timer = 60,
      .full_hit_points = Constants.SpiderHitPoints,
      .personality = switch (gs.getRand().range(u32, 0, 2)) {
        0 => C.Monster.Personality.Chase,
        else => C.Monster.Personality.Wander,
      },
      .kill_points = Constants.SpiderKillPoints,
      .next_shoot_timer = gs.getRand().range(u32, 75, 400),
    });

    return entity_id;
  }
};

pub const Squid = struct{
  pub const Params = struct{
    pos: Math.Vec2,
  };

  pub fn spawn(gs: *GameSession, params: Params) EntityId {
    const entity_id = gs.spawn();

    gs.transforms.create(entity_id, C.Transform{
      .pos = params.pos,
    });

    gs.phys_objects.create(entity_id, C.PhysObject{
      .world_bbox = world_bbox,
      .entity_bbox = monster_entity_bbox,
      .facing = Math.Direction.E,
      .speed = 0,
      .push_dir = null,
      .owner_id = EntityId{ .id = 0 },
      .ignore_pits = false,
      .flags = C.PhysObject.FLAG_MONSTER,
      .ignore_flags = 0,
      .internal = undefined,
    });

    gs.drawables.create(entity_id, C.Drawable{
      .drawType = C.Drawable.Type.Squid,
      .z_index = Constants.ZIndexEnemy,
    });

    gs.creatures.create(entity_id, C.Creature{
      .invulnerability_timer = 0,
      .hit_points = 1,
      .walk_speed = Constants.SquidWalkSpeed,
    });

    gs.monsters.create(entity_id, C.Monster{
      .spawning_timer = 60,
      .full_hit_points = Constants.SquidHitPoints,
      .personality = switch (gs.getRand().range(u32, 0, 2)) {
        0 => C.Monster.Personality.Chase,
        else => C.Monster.Personality.Wander,
      },
      .kill_points = Constants.SquidKillPoints,
      .next_shoot_timer = gs.getRand().range(u32, 75, 400),
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
    inflictor_player_controller_id: ?EntityId,
    owner_id: EntityId,
    pos: Math.Vec2,
    facing: Math.Direction,
    bullet_type: BulletType,
    cluster_size: u32,
  };

  pub fn spawn(gs: *GameSession, params: Params) EntityId {
    const entity_id = gs.spawn();

    gs.transforms.create(entity_id, C.Transform{
      .pos = params.pos,
    });

    const bullet_size = 4 * GRIDSIZE_PIXELS;
    const min = GRIDSIZE_SUBPIXELS / 2 - bullet_size / 2;
    const max = min + bullet_size - 1;

    gs.phys_objects.create(entity_id, C.PhysObject{
      .world_bbox = Math.BoundingBox{
        .mins = Math.Vec2.init(min, min),
        .maxs = Math.Vec2.init(max, max),
      },
      .entity_bbox = Math.BoundingBox{
        .mins = Math.Vec2.init(min, min),
        .maxs = Math.Vec2.init(max, max),
      },
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
        BulletType.MonsterBullet => C.PhysObject.FLAG_MONSTER,
        BulletType.PlayerBullet => 0,
      },
      .internal = undefined,
    });

    gs.drawables.create(entity_id, C.Drawable{
      .drawType = switch (params.bullet_type) {
        BulletType.MonsterBullet => C.Drawable.Type.MonsterBullet,
        BulletType.PlayerBullet => switch (params.cluster_size) {
          1 => C.Drawable.Type.PlayerBullet,
          2 => C.Drawable.Type.PlayerBullet2,
          else => C.Drawable.Type.PlayerBullet3,
        },
      },
      .z_index = Constants.ZIndexBullet,
    });

    gs.bullets.create(entity_id, C.Bullet{
      .inflictor_player_controller_id = params.inflictor_player_controller_id,
      .damage = params.cluster_size,
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

  pub fn spawn(gs: *GameSession, params: Params) EntityId {
    const entity_id = gs.spawn();

    gs.transforms.create(entity_id, C.Transform{
      .pos = params.pos,
    });

    gs.drawables.create(entity_id, C.Drawable{
      .drawType = C.Drawable.Type.Animation,
      .z_index = params.z_index,
    });

    gs.animations.create(entity_id, C.Animation{
      .simple_anim = params.simple_anim,
      .frame_index = 0,
      .ticks = 0,
    });

    return entity_id;
  }
};

pub const Pickup = struct{
  pub const Params = struct{
    pos: Math.Vec2,
    pickup_type: C.Pickup.Type,
  };

  pub fn spawn(gs: *GameSession, params: Params) EntityId {
    const entity_id = gs.spawn();

    gs.transforms.create(entity_id, C.Transform{
      .pos = params.pos,
    });

    gs.drawables.create(entity_id, C.Drawable{
      .drawType = C.Drawable.Type.Pickup,
      .z_index = Constants.ZIndexPickup,
    });

    gs.phys_objects.create(entity_id, C.PhysObject{
      .world_bbox = world_bbox,
      .entity_bbox = pickup_entity_bbox,
      .facing = Math.Direction.E,
      .speed = 0,
      .push_dir = null,
      .owner_id = EntityId{ .id = 0 },
      .ignore_pits = false,
      .flags = 0,
      .ignore_flags = C.PhysObject.FLAG_BULLET | C.PhysObject.FLAG_MONSTER,
      .internal = undefined,
    });

    gs.pickups.create(entity_id, C.Pickup{
      .pickup_type = params.pickup_type,
      .timer = 15*60, // will disappear in 15 seconds
    });

    return entity_id;
  }
};

pub const EventCollide = struct{
  pub fn spawn(gs: *GameSession, body: C.EventCollide) EntityId {
    const entity_id = gs.spawn();
    gs.event_collides.create(entity_id, body);
    return entity_id;
  }
};

pub const EventConferBonus = struct{
  pub fn spawn(gs: *GameSession, body: C.EventConferBonus) EntityId {
    const entity_id = gs.spawn();
    gs.event_confer_bonuses.create(entity_id, body);
    return entity_id;
  }
};

pub const EventAwardPoints = struct{
  pub fn spawn(gs: *GameSession, body: C.EventAwardPoints) EntityId {
    const entity_id = gs.spawn();
    gs.event_award_pointses.create(entity_id, body);
    return entity_id;
  }
};

pub const EventTakeDamage = struct{
  pub fn spawn(gs: *GameSession, body: C.EventTakeDamage) EntityId {
    const entity_id = gs.spawn();
    gs.event_take_damages.create(entity_id, body);
    return entity_id;
  }
};

pub const EventPlayerDied = struct{
  pub fn spawn(gs: *GameSession) EntityId {
    const entity_id = gs.spawn();
    gs.event_player_dieds.create(entity_id, C.EventPlayerDied{.unused = true});
    return entity_id;
  }
};
