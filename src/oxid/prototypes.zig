const zang = @import("zang");
const gbe = @import("gbe");
const math = @import("../common/math.zig");
const Graphic = @import("graphics.zig").Graphic;
const SimpleAnim = @import("graphics.zig").SimpleAnim;
const getSimpleAnim = @import("graphics.zig").getSimpleAnim;
const GameSession = @import("game.zig").GameSession;
const GRIDSIZE_PIXELS = @import("level.zig").GRIDSIZE_PIXELS;
const GRIDSIZE_SUBPIXELS = @import("level.zig").GRIDSIZE_SUBPIXELS;
const ConstantTypes = @import("constant_types.zig");
const Constants = @import("constants.zig");
const c = @import("components.zig");
const audio = @import("audio.zig");

fn make_bbox(diameter: u31) math.BoundingBox {
    const graphic_diameter = GRIDSIZE_SUBPIXELS;
    const min = graphic_diameter / 2 - diameter / 2;
    const max = graphic_diameter / 2 + diameter / 2 - 1;
    return math.BoundingBox{
        .mins = math.Vec2.init(min, min),
        .maxs = math.Vec2.init(max, max),
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
    break :blk math.BoundingBox{
        .mins = math.Vec2.init(min, min),
        .maxs = math.Vec2.init(max, max),
    };
};

pub const MainController = struct {
    pub const Params = struct {
        high_score: u32,
    };

    pub fn spawn(gs: *GameSession, params: Params) !gbe.EntityId {
        const entity_id = gs.spawn();
        errdefer gs.undoSpawn(entity_id);

        try gs.addComponent(entity_id, c.MainController{
            .high_score = params.high_score,
            .new_high_score = false,
            .game_running_state = null,
        });

        return entity_id;
    }
};

pub const GameController = struct {
    pub fn spawn(gs: *GameSession) !gbe.EntityId {
        const entity_id = gs.spawn();
        errdefer gs.undoSpawn(entity_id);

        try gs.addComponent(entity_id, c.GameController{
            .game_over = false,
            .monster_count = 0,
            .enemy_speed_level = 0,
            .enemy_speed_timer = Constants.EnemySpeedTicks,
            .wave_number = 0,
            .next_wave_timer = 90,
            .next_pickup_timer = 15*60,
            .freeze_monsters_timer = 0,
            .extra_lives_spawned = 0,
            .wave_message = null,
            .wave_message_timer = 0,
        });

        return entity_id;
    }
};

pub const PlayerController = struct {
    pub fn spawn(gs: *GameSession) !gbe.EntityId {
        const entity_id = gs.spawn();
        errdefer gs.undoSpawn(entity_id);

        try gs.addComponent(entity_id, c.PlayerController{
            .player_id = null,
            .lives = Constants.PlayerNumLives,
            .score = 0,
            .respawn_timer = 1,
        });

        return entity_id;
    }
};

pub const Player = struct {
    pub const Params = struct {
        player_controller_id: gbe.EntityId,
        pos: math.Vec2,
    };

    pub fn spawn(gs: *GameSession, params: Params) !gbe.EntityId {
        const entity_id = gs.spawn();
        errdefer gs.undoSpawn(entity_id);

        try gs.addComponent(entity_id, c.Transform{
            .pos = math.Vec2.init(params.pos.x, params.pos.y + GRIDSIZE_SUBPIXELS),
        });

        try gs.addComponent(entity_id, c.PhysObject{
            .illusory = true, // illusory during invulnerability stage
            .world_bbox = world_bbox,
            .entity_bbox = player_entity_bbox,
            .facing = math.Direction.E,
            .speed = 0,
            .push_dir = null,
            .owner_id = gbe.EntityId{ .id = 0 },
            .ignore_pits = false,
            .flags = 0,
            .ignore_flags = 0,
            .internal = undefined,
        });

        try gs.addComponent(entity_id, c.Creature{
            .invulnerability_timer = Constants.InvulnerabilityTime,
            .hit_points = 1,
            .flinch_timer = 0,
            .god_mode = false,
        });

        try gs.addComponent(entity_id, c.Player{
            .player_controller_id = params.player_controller_id,
            .trigger_released = true,
            .bullets = []?gbe.EntityId{null} ** Constants.PlayerMaxBullets,
            .attack_level = c.Player.AttackLevel.One,
            .speed_level = c.Player.SpeedLevel.One,
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

pub const PlayerCorpse = struct {
    pub const Params = struct {
        pos: math.Vec2,
    };

    pub fn spawn(gs: *GameSession, params: Params) !gbe.EntityId {
        const entity_id = gs.spawn();
        errdefer gs.undoSpawn(entity_id);

        try gs.addComponent(entity_id, c.Transform{
            .pos = params.pos,
        });

        try gs.addComponent(entity_id, c.SimpleGraphic{
            .graphic = Graphic.ManDying6,
            .z_index = Constants.ZIndexCorpse,
            .directional = false,
        });

        return entity_id;
    }
};

pub const Monster = struct {
    pub const Params = struct {
        wave_number: u32,
        monster_type: ConstantTypes.MonsterType,
        pos: math.Vec2,
        has_coin: bool,
    };

    pub fn spawn(gs: *GameSession, params: Params) !gbe.EntityId {
        const monster_values = Constants.getMonsterValues(params.monster_type);

        const entity_id = gs.spawn();
        errdefer gs.undoSpawn(entity_id);

        try gs.addComponent(entity_id, c.Transform{
            .pos = params.pos,
        });

        try gs.addComponent(entity_id, c.PhysObject{
            .illusory = false,
            .world_bbox = world_bbox,
            .entity_bbox = monster_entity_bbox,
            .facing = math.Direction.E,
            .speed = 0,
            .push_dir = null,
            .owner_id = gbe.EntityId{ .id = 0 },
            .ignore_pits = false,
            .flags = c.PhysObject.FLAG_MONSTER,
            .ignore_flags = 0,
            .internal = undefined,
        });

        try gs.addComponent(entity_id, c.Creature{
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

        try gs.addComponent(entity_id, c.Monster{
            .monster_type = params.monster_type,
            .spawning_timer = Constants.MonsterSpawnTime,
            .full_hit_points = monster_values.hit_points,
            .personality =
                if (params.monster_type == ConstantTypes.MonsterType.Juggernaut)
                    c.Monster.Personality.Chase
                else
                    switch (gs.getRand().range(u32, 0, 2)) {
                        0 => c.Monster.Personality.Chase,
                        else => c.Monster.Personality.Wander,
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

pub const Web = struct {
    pub const Params = struct {
        pos: math.Vec2,
    };

    pub fn spawn(gs: *GameSession, params: Params) !gbe.EntityId {
        const entity_id = gs.spawn();
        errdefer gs.undoSpawn(entity_id);

        try gs.addComponent(entity_id, c.Transform{
            .pos = params.pos,
        });

        try gs.addComponent(entity_id, c.PhysObject{
            .illusory = true,
            .world_bbox = world_bbox,
            .entity_bbox = monster_entity_bbox,
            .facing = math.Direction.E,
            .speed = 0,
            .push_dir = null,
            .owner_id = gbe.EntityId{ .id = 0 },
            .ignore_pits = false,
            .flags = c.PhysObject.FLAG_WEB,
            .ignore_flags = 0,
            .internal = undefined,
        });

        try gs.addComponent(entity_id, c.Web{});

        try gs.addComponent(entity_id, c.Creature{
            .invulnerability_timer = 0,
            .hit_points = 3,
            .flinch_timer = 0,
            .god_mode = false,
        });

        return entity_id;
    }
};

pub const Bullet = struct {
    pub const BulletType = enum{
        MonsterBullet,
        PlayerBullet,
    };

    pub const Params = struct {
        inflictor_player_controller_id: ?gbe.EntityId,
        owner_id: gbe.EntityId,
        pos: math.Vec2,
        facing: math.Direction,
        bullet_type: BulletType,
        cluster_size: u32,
    };

    pub fn spawn(gs: *GameSession, params: Params) !gbe.EntityId {
        const entity_id = gs.spawn();
        errdefer gs.undoSpawn(entity_id);

        try gs.addComponent(entity_id, c.Transform{
            .pos = params.pos,
        });

        try gs.addComponent(entity_id, c.PhysObject{
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
            .flags = c.PhysObject.FLAG_BULLET,
            .ignore_flags = c.PhysObject.FLAG_BULLET | switch (params.bullet_type) {
                // monster bullets ignore all monsters and webs
                BulletType.MonsterBullet => c.PhysObject.FLAG_MONSTER | c.PhysObject.FLAG_WEB,
                // player bullets ignore only the player that shot it (via `owner_id`)
                BulletType.PlayerBullet => 0,
            },
            .internal = undefined,
        });

        try gs.addComponent(entity_id, c.Bullet{
            .inflictor_player_controller_id = params.inflictor_player_controller_id,
            .damage = params.cluster_size,
            .line_of_fire = null,
        });

        try gs.addComponent(entity_id, c.SimpleGraphic{
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

pub const Animation = struct {
    pub const Params = struct {
        pos: math.Vec2,
        simple_anim: SimpleAnim,
        z_index: u32,
    };

    pub fn spawn(gs: *GameSession, params: Params) !gbe.EntityId {
        const entity_id = gs.spawn();
        errdefer gs.undoSpawn(entity_id);

        try gs.addComponent(entity_id, c.Transform{
            .pos = params.pos,
        });

        try gs.addComponent(entity_id, c.Animation{
            .simple_anim = params.simple_anim,
            .frame_index = 0,
            .frame_timer = getSimpleAnim(params.simple_anim).ticks_per_frame,
            .z_index = params.z_index,
        });

        return entity_id;
    }
};

pub const Pickup = struct {
    pub const Params = struct {
        pos: math.Vec2,
        pickup_type: ConstantTypes.PickupType,
    };

    pub fn spawn(gs: *GameSession, params: Params) !gbe.EntityId {
        const pickup_values = Constants.getPickupValues(params.pickup_type);

        const entity_id = gs.spawn();
        errdefer gs.undoSpawn(entity_id);

        try gs.addComponent(entity_id, c.Transform{
            .pos = params.pos,
        });

        try gs.addComponent(entity_id, c.SimpleGraphic{
            .graphic = switch (params.pickup_type) {
                ConstantTypes.PickupType.PowerUp => Graphic.PowerUp,
                ConstantTypes.PickupType.SpeedUp => Graphic.SpeedUp,
                ConstantTypes.PickupType.LifeUp => Graphic.LifeUp,
                ConstantTypes.PickupType.Coin => Graphic.Coin,
            },
            .z_index = Constants.ZIndexPickup,
            .directional = false,
        });

        try gs.addComponent(entity_id, c.PhysObject{
            .illusory = true,
            .world_bbox = world_bbox,
            .entity_bbox = pickup_entity_bbox,
            .facing = math.Direction.E,
            .speed = 0,
            .push_dir = null,
            .owner_id = gbe.EntityId{ .id = 0 },
            .ignore_pits = false,
            .flags = 0,
            .ignore_flags = c.PhysObject.FLAG_BULLET | c.PhysObject.FLAG_MONSTER,
            .internal = undefined,
        });

        try gs.addComponent(entity_id, c.Pickup{
            .pickup_type = params.pickup_type,
            .get_points = pickup_values.get_points,
            .message = pickup_values.message,
        });

        try gs.addComponent(entity_id, c.RemoveTimer {
            .timer = pickup_values.lifetime,
        });

        return entity_id;
    }
};

pub const Sound = struct {
    pub const Params = struct {
        duration: f32,
        wrapper: c.Voice.WrapperU,
    };

    pub fn spawn(gs: *GameSession, params: Params) !gbe.EntityId {
        const entity_id = gs.spawn();
        errdefer gs.undoSpawn(entity_id);

        try gs.addComponent(entity_id, c.Voice {
            .wrapper = params.wrapper,
        });

        try gs.addComponent(entity_id, c.RemoveTimer {
            .timer = @floatToInt(u32, params.duration * 60.0),
        });

        return entity_id;
    }
};

fn Event(comptime T: type) type {
    return struct {
        pub fn spawn(gs: *GameSession, body: T) !gbe.EntityId {
            const entity_id = gs.spawn();
            errdefer gs.undoSpawn(entity_id);

            try gs.addComponent(entity_id, body);

            return entity_id;
        }
    };
}

pub const EventAwardLife = Event(c.EventAwardLife);
pub const EventAwardPoints = Event(c.EventAwardPoints);
pub const EventCollide = Event(c.EventCollide);
pub const EventConferBonus = Event(c.EventConferBonus);
pub const EventDraw = Event(c.EventDraw);
pub const EventDrawBox = Event(c.EventDrawBox);
pub const EventInput = Event(c.EventInput);
pub const EventMonsterDied = Event(c.EventMonsterDied);
pub const EventPlayerDied = Event(c.EventPlayerDied);
pub const EventPlayerOutOfLives = Event(c.EventPlayerOutOfLives);
pub const EventPostScore = Event(c.EventPostScore);
pub const EventQuit = Event(c.EventQuit);
pub const EventSaveHighScore = Event(c.EventSaveHighScore);
pub const EventShowMessage = Event(c.EventShowMessage);
pub const EventTakeDamage = Event(c.EventTakeDamage);

pub fn playSample(gs: *GameSession, sample: audio.Sample) void {
    _ = Sound.spawn(gs, Sound.Params {
        .duration = 2.0,
        .wrapper = c.Voice.WrapperU {
            .Sample = c.Voice.Wrapper(zang.Sampler, audio.SamplerNoteParams) {
                .initial_params = null,
                .initial_sample = sample,
                .iq = zang.Notes(audio.SamplerNoteParams).ImpulseQueue.init(),
                .module = zang.Sampler.init(),
                .trigger = zang.Trigger(audio.SamplerNoteParams).init(),
            },
        },
    }) catch undefined;
}

pub fn playSynth(gs: *GameSession, params: var) void {
    _ = Sound.spawn(gs, switch (@typeOf(params)) {
        audio.AccelerateVoice.NoteParams => Sound.Params {
            .duration = audio.AccelerateVoice.SoundDuration,
            .wrapper = c.Voice.WrapperU {
                .Accelerate = c.Voice.Wrapper(audio.AccelerateVoice, audio.AccelerateVoice.NoteParams) {
                    .initial_params = params,
                    .initial_sample = null,
                    .iq = zang.Notes(audio.AccelerateVoice.NoteParams).ImpulseQueue.init(),
                    .module = audio.AccelerateVoice.init(),
                    .trigger = zang.Trigger(audio.AccelerateVoice.NoteParams).init(),
                },
            },
        },
        audio.CoinVoice.NoteParams => Sound.Params {
            .duration = audio.CoinVoice.SoundDuration,
            .wrapper = c.Voice.WrapperU {
                .Coin = c.Voice.Wrapper(audio.CoinVoice, audio.CoinVoice.NoteParams) {
                    .initial_params = params,
                    .initial_sample = null,
                    .iq = zang.Notes(audio.CoinVoice.NoteParams).ImpulseQueue.init(),
                    .module = audio.CoinVoice.init(),
                    .trigger = zang.Trigger(audio.CoinVoice.NoteParams).init(),
                },
            },
        },
        audio.ExplosionVoice.NoteParams => Sound.Params {
            .duration = audio.ExplosionVoice.SoundDuration,
            .wrapper = c.Voice.WrapperU {
                .Explosion = c.Voice.Wrapper(audio.ExplosionVoice, audio.ExplosionVoice.NoteParams) {
                    .initial_params = params,
                    .initial_sample = null,
                    .iq = zang.Notes(audio.ExplosionVoice.NoteParams).ImpulseQueue.init(),
                    .module = audio.ExplosionVoice.init(),
                    .trigger = zang.Trigger(audio.ExplosionVoice.NoteParams).init(),
                },
            },
        },
        audio.LaserVoice.NoteParams => Sound.Params {
            .duration = audio.LaserVoice.SoundDuration,
            .wrapper = c.Voice.WrapperU {
                .Laser = c.Voice.Wrapper(audio.LaserVoice, audio.LaserVoice.NoteParams) {
                    .initial_params = params,
                    .initial_sample = null,
                    .iq = zang.Notes(audio.LaserVoice.NoteParams).ImpulseQueue.init(),
                    .module = audio.LaserVoice.init(),
                    .trigger = zang.Trigger(audio.LaserVoice.NoteParams).init(),
                },
            },
        },
        audio.WaveBeginVoice.NoteParams => Sound.Params {
            .duration = audio.WaveBeginVoice.SoundDuration,
            .wrapper = c.Voice.WrapperU {
                .WaveBegin = c.Voice.Wrapper(audio.WaveBeginVoice, audio.WaveBeginVoice.NoteParams) {
                    .initial_params = params,
                    .initial_sample = null,
                    .iq = zang.Notes(audio.WaveBeginVoice.NoteParams).ImpulseQueue.init(),
                    .module = audio.WaveBeginVoice.init(),
                    .trigger = zang.Trigger(audio.WaveBeginVoice.NoteParams).init(),
                },
            },
        },
        else => unreachable,
    }) catch undefined;
}
