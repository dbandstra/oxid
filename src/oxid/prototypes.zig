const zang = @import("zang");
const gbe = @import("gbe");
const math = @import("../common/math.zig");
const Graphic = @import("graphics.zig").Graphic;
const SimpleAnim = @import("graphics.zig").SimpleAnim;
const getSimpleAnim = @import("graphics.zig").getSimpleAnim;
const GameSession = @import("game.zig").GameSession;
const levels = @import("levels.zig");
const ConstantTypes = @import("constant_types.zig");
const constants = @import("constants.zig");
const c = @import("components.zig");
const audio = @import("audio.zig");

fn make_bbox(diameter: u31) math.BoundingBox {
    const graphic_diameter = levels.subpixels_per_tile;
    const min = graphic_diameter / 2 - diameter / 2;
    const max = graphic_diameter / 2 + diameter / 2 - 1;
    return .{
        .mins = math.Vec2.init(min, min),
        .maxs = math.Vec2.init(max, max),
    };
}

// all entities are full size for colliding with the level
const world_bbox = make_bbox(levels.subpixels_per_tile);
// player's ent-vs-ent bbox is 50% size
const player_entity_bbox = make_bbox(levels.subpixels_per_tile / 2);
// monster's ent-vs-ent bbox is 75% size
const monster_entity_bbox = make_bbox(levels.subpixels_per_tile * 3 / 4);
// pickups are 75% size
const pickup_entity_bbox = make_bbox(levels.subpixels_per_tile * 3 / 4);

pub const bullet_bbox = blk: {
    const bullet_size = 4 * levels.pixels_per_tile;
    const min = levels.subpixels_per_tile / 2 - bullet_size / 2;
    const max = min + bullet_size - 1;
    break :blk math.BoundingBox {
        .mins = math.Vec2.init(min, min),
        .maxs = math.Vec2.init(max, max),
    };
};

pub const MainController = struct {
    pub fn spawn(gs: *GameSession) !gbe.EntityId {
        const entity_id = gs.ecs.spawn();
        errdefer gs.ecs.undoSpawn(entity_id);

        try gs.ecs.addComponent(entity_id, c.MainController {
            .game_running_state = null,
        });

        return entity_id;
    }
};

pub const GameController = struct {
    pub const Params = struct {
        num_players: u32,
    };

    pub fn spawn(gs: *GameSession, params: Params) !gbe.EntityId {
        const entity_id = gs.ecs.spawn();
        errdefer gs.ecs.undoSpawn(entity_id);

        try gs.ecs.addComponent(entity_id, c.GameController {
            .monster_count = 0,
            .enemy_speed_level = 0,
            .enemy_speed_timer = constants.enemy_speed_ticks,
            .wave_number = 0,
            .next_wave_timer = constants.duration60(90),
            .next_pickup_timer = constants.duration60(15*60),
            .freeze_monsters_timer = 0,
            .extra_lives_spawned = 0,
            .wave_message = null,
            .wave_message_timer = 0,
            .num_players_remaining = params.num_players,
        });

        return entity_id;
    }
};

pub const PlayerController = struct {
    pub const Params = struct {
        player_number: u32,
    };

    pub fn spawn(gs: *GameSession, params: Params) !gbe.EntityId {
        const entity_id = gs.ecs.spawn();
        errdefer gs.ecs.undoSpawn(entity_id);

        try gs.ecs.addComponent(entity_id, c.PlayerController {
            .player_number = params.player_number,
            .player_id = null,
            .lives = constants.player_num_lives,
            .score = 0,
            .respawn_timer = 1,
        });

        return entity_id;
    }
};

pub const Player = struct {
    pub const Params = struct {
        player_number: u32,
        player_controller_id: gbe.EntityId,
        pos: math.Vec2,
    };

    pub fn spawn(gs: *GameSession, params: Params) !gbe.EntityId {
        const entity_id = gs.ecs.spawn();
        errdefer gs.ecs.undoSpawn(entity_id);

        try gs.ecs.addComponent(entity_id, c.Transform {
            .pos = math.Vec2.init(params.pos.x, params.pos.y + levels.subpixels_per_tile),
        });

        try gs.ecs.addComponent(entity_id, c.PhysObject {
            .illusory = true, // illusory during invulnerability stage
            .world_bbox = world_bbox,
            .entity_bbox = player_entity_bbox,
            .facing = .e,
            .speed = 0,
            .push_dir = null,
            .owner_id = gbe.EntityId.zero,
            .flags = c.PhysObject.FLAG_PLAYER,
            .ignore_flags = c.PhysObject.FLAG_PLAYER,
            .internal = undefined,
        });

        try gs.ecs.addComponent(entity_id, c.Creature {
            .invulnerability_timer = constants.invulnerability_time,
            .hit_points = 1,
            .flinch_timer = 0,
            .god_mode = false,
        });

        try gs.ecs.addComponent(entity_id, c.Player {
            .player_number = params.player_number,
            .player_controller_id = params.player_controller_id,
            .trigger_released = true,
            .bullets = [_]?gbe.EntityId{null} ** constants.player_max_bullets,
            .attack_level = .one,
            .speed_level = .one,
            .spawn_anim_y_remaining = levels.subpixels_per_tile, // will animate upwards 1 tile upon spawning
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
        const entity_id = gs.ecs.spawn();
        errdefer gs.ecs.undoSpawn(entity_id);

        try gs.ecs.addComponent(entity_id, c.Transform {
            .pos = params.pos,
        });

        try gs.ecs.addComponent(entity_id, c.SimpleGraphic {
            .graphic = .man_dying6,
            .z_index = constants.z_index_corpse,
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
        const monster_values = constants.getMonsterValues(params.monster_type);

        const entity_id = gs.ecs.spawn();
        errdefer gs.ecs.undoSpawn(entity_id);

        try gs.ecs.addComponent(entity_id, c.Transform {
            .pos = params.pos,
        });

        try gs.ecs.addComponent(entity_id, c.PhysObject {
            .illusory = false,
            .world_bbox = world_bbox,
            .entity_bbox = monster_entity_bbox,
            .facing = .e,
            .speed = 0,
            .push_dir = null,
            .owner_id = gbe.EntityId.zero,
            .flags = c.PhysObject.FLAG_MONSTER,
            .ignore_flags = 0,
            .internal = undefined,
        });

        try gs.ecs.addComponent(entity_id, c.Creature {
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

        try gs.ecs.addComponent(entity_id, c.Monster {
            .monster_type = params.monster_type,
            .spawning_timer = constants.monster_spawn_time,
            .full_hit_points = monster_values.hit_points,
            .personality =
                if (params.monster_type == .juggernaut)
                    c.Monster.Personality.chase
                else
                    switch (gs.getRand().range(u32, 0, 2)) {
                        0 => c.Monster.Personality.chase,
                        else => c.Monster.Personality.wander,
                    },
            .kill_points = monster_values.kill_points,
            .can_shoot = can_shoot,
            .can_drop_webs = monster_values.can_drop_webs,
            .next_attack_timer =
                if (can_shoot or monster_values.can_drop_webs)
                    constants.duration60(gs.getRand().range(u31, 75, 400))
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
        const entity_id = gs.ecs.spawn();
        errdefer gs.ecs.undoSpawn(entity_id);

        try gs.ecs.addComponent(entity_id, c.Transform {
            .pos = params.pos,
        });

        try gs.ecs.addComponent(entity_id, c.PhysObject {
            .illusory = true,
            .world_bbox = world_bbox,
            .entity_bbox = monster_entity_bbox,
            .facing = .e,
            .speed = 0,
            .push_dir = null,
            .owner_id = gbe.EntityId.zero,
            .flags = c.PhysObject.FLAG_WEB,
            .ignore_flags = 0,
            .internal = undefined,
        });

        try gs.ecs.addComponent(entity_id, c.Web {});

        try gs.ecs.addComponent(entity_id, c.Creature {
            .invulnerability_timer = 0,
            .hit_points = 3,
            .flinch_timer = 0,
            .god_mode = false,
        });

        return entity_id;
    }
};

pub const Bullet = struct {
    pub const Params = struct {
        inflictor_player_controller_id: ?gbe.EntityId,
        owner_id: gbe.EntityId,
        pos: math.Vec2,
        facing: math.Direction,
        bullet_type: c.Bullet.Type,
        cluster_size: u32,
        friendly_fire: bool,
    };

    pub fn spawn(gs: *GameSession, params: Params) !gbe.EntityId {
        const entity_id = gs.ecs.spawn();
        errdefer gs.ecs.undoSpawn(entity_id);

        try gs.ecs.addComponent(entity_id, c.Transform {
            .pos = params.pos,
        });

        try gs.ecs.addComponent(entity_id, c.PhysObject {
            .illusory = true,
            .world_bbox = bullet_bbox,
            .entity_bbox = bullet_bbox,
            .facing = params.facing,
            .speed = switch (params.bullet_type) {
                .monster_bullet => constants.monster_bullet_speed,
                .player_bullet => constants.player_bullet_speed,
            },
            .push_dir = null,
            .owner_id = params.owner_id,
            .flags = c.PhysObject.FLAG_BULLET,
            .ignore_flags = c.PhysObject.FLAG_BULLET | switch (params.bullet_type) {
                // monster bullets ignore all monsters and webs
                .monster_bullet =>
                    c.PhysObject.FLAG_MONSTER | c.PhysObject.FLAG_WEB,
                // player bullets ignore only the player that shot it (via
                // `owner_id`), unless friendly fire is disabled.
                // see also src/oxid/set_friendly_fire.zig, where this value
                // is changed (called when user toggles friendly fire in the
                // menu)
                .player_bullet =>
                    if (!params.friendly_fire) c.PhysObject.FLAG_PLAYER else 0,
            },
            .internal = undefined,
        });

        try gs.ecs.addComponent(entity_id, c.Bullet {
            .bullet_type = params.bullet_type,
            .inflictor_player_controller_id = params.inflictor_player_controller_id,
            .damage = params.cluster_size,
            .line_of_fire = null,
        });

        try gs.ecs.addComponent(entity_id, c.SimpleGraphic {
            .graphic = switch (params.bullet_type) {
                .monster_bullet => Graphic.mon_bullet,
                .player_bullet => switch (params.cluster_size) {
                    1 => Graphic.pla_bullet,
                    2 => Graphic.pla_bullet2,
                    else => Graphic.pla_bullet3,
                },
            },
            .z_index = constants.z_index_bullet,
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
        const entity_id = gs.ecs.spawn();
        errdefer gs.ecs.undoSpawn(entity_id);

        try gs.ecs.addComponent(entity_id, c.Transform {
            .pos = params.pos,
        });

        try gs.ecs.addComponent(entity_id, c.Animation {
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
        const pickup_values = constants.getPickupValues(params.pickup_type);

        const entity_id = gs.ecs.spawn();
        errdefer gs.ecs.undoSpawn(entity_id);

        try gs.ecs.addComponent(entity_id, c.Transform {
            .pos = params.pos,
        });

        try gs.ecs.addComponent(entity_id, c.SimpleGraphic {
            .graphic = switch (params.pickup_type) {
                .power_up => .power_up,
                .speed_up => .speed_up,
                .life_up => .life_up,
                .coin => .coin,
            },
            .z_index = constants.z_index_pickup,
            .directional = false,
        });

        try gs.ecs.addComponent(entity_id, c.PhysObject {
            .illusory = true,
            .world_bbox = world_bbox,
            .entity_bbox = pickup_entity_bbox,
            .facing = .e,
            .speed = 0,
            .push_dir = null,
            .owner_id = gbe.EntityId.zero,
            .flags = 0,
            .ignore_flags = c.PhysObject.FLAG_BULLET | c.PhysObject.FLAG_MONSTER,
            .internal = undefined,
        });

        try gs.ecs.addComponent(entity_id, c.Pickup {
            .pickup_type = params.pickup_type,
            .get_points = pickup_values.get_points,
            .message = pickup_values.message,
        });

        try gs.ecs.addComponent(entity_id, c.RemoveTimer {
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
        const entity_id = gs.ecs.spawn();
        errdefer gs.ecs.undoSpawn(entity_id);

        try gs.ecs.addComponent(entity_id, c.Voice {
            .wrapper = params.wrapper,
        });

        // FIXME!!! this timer will be paused when you're in the menu, but we
        // use sounds in the menu too!
        try gs.ecs.addComponent(entity_id, c.RemoveTimer {
            .timer = @floatToInt(u32, params.duration * @as(f32, constants.ticks_per_second)),
        });

        return entity_id;
    }
};

fn Event(comptime T: type) type {
    return struct {
        pub fn spawn(gs: *GameSession, body: T) !gbe.EntityId {
            const entity_id = gs.ecs.spawn();
            errdefer gs.ecs.undoSpawn(entity_id);

            try gs.ecs.addComponent(entity_id, body);

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
pub const EventGameInput = Event(c.EventGameInput);
pub const EventGameOver = Event(c.EventGameOver);
pub const EventMonsterDied = Event(c.EventMonsterDied);
pub const EventPlayerDied = Event(c.EventPlayerDied);
pub const EventPlayerOutOfLives = Event(c.EventPlayerOutOfLives);
pub const EventShowMessage = Event(c.EventShowMessage);
pub const EventTakeDamage = Event(c.EventTakeDamage);

pub fn playSample(gs: *GameSession, sample: audio.Sample) void {
    _ = Sound.spawn(gs, .{
        .duration = 2.0,
        .wrapper = .{
            .sample = .{
                .initial_params = null,
                .initial_sample = sample,
                .iq = zang.Notes(audio.SamplerNoteParams).ImpulseQueue.init(),
                .idgen = zang.IdGenerator.init(),
                .module = zang.Sampler.init(),
                .trigger = zang.Trigger(audio.SamplerNoteParams).init(),
            },
        },
    }) catch undefined;
}

pub fn playSynth(
    gs: *GameSession,
    comptime name: []const u8,
    comptime VoiceType: type,
    params: VoiceType.NoteParams,
) void {
    _ = Sound.spawn(gs, .{
        .duration = VoiceType.sound_duration,
        .wrapper = @unionInit(c.Voice.WrapperU, name, .{
            .initial_params = params,
            .initial_sample = null,
            .iq = zang.Notes(VoiceType.NoteParams).ImpulseQueue.init(),
            .idgen = zang.IdGenerator.init(),
            .module = VoiceType.init(),
            .trigger = zang.Trigger(VoiceType.NoteParams).init(),
        }),
    }) catch undefined;
}
