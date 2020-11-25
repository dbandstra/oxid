const zang = @import("zang");
const gbe = @import("gbe");
const math = @import("../common/math.zig");
const graphics = @import("graphics.zig");
const game = @import("game.zig");
const levels = @import("levels.zig");
const constants = @import("constants.zig");
const c = @import("components.zig");

fn makeBBox(diameter: u31) math.Box {
    const graphic_diameter = levels.subpixels_per_tile;
    const min = graphic_diameter / 2 - diameter / 2;
    const max = graphic_diameter / 2 + diameter / 2 - 1;
    return .{
        .mins = math.vec2(min, min),
        .maxs = math.vec2(max, max),
    };
}

// all entities are full size for colliding with the level
const world_bbox = makeBBox(levels.subpixels_per_tile);
// player's ent-vs-ent bbox is 50% size
const player_entity_bbox = makeBBox(levels.subpixels_per_tile / 2);
// monster's ent-vs-ent bbox is 75% size
const monster_entity_bbox = makeBBox(levels.subpixels_per_tile * 3 / 4);
// pickups are 75% size
const pickup_entity_bbox = makeBBox(levels.subpixels_per_tile * 3 / 4);

pub const bullet_bbox = blk: {
    const bullet_size = 4 * levels.pixels_per_tile;
    const min = levels.subpixels_per_tile / 2 - bullet_size / 2;
    const max = min + bullet_size - 1;
    break :blk math.Box{
        .mins = math.vec2(min, min),
        .maxs = math.vec2(max, max),
    };
};

// currently, i can't pass a tuple to this function, due to a zig compiler bug (the program will
// crash at runtime). so the explicit @"0", @"1", etc. syntax i'm using is only there until the
// bug is fixed.
// see https://github.com/ziglang/zig/issues/3915
inline fn spawnWithComponents(gs: *game.Session, components: anytype) ?gbe.EntityId {
    const entity_id = gs.ecs.spawn();
    inline for (@typeInfo(@TypeOf(components)).Struct.fields) |field| {
        if (@typeInfo(field.field_type) == .Optional) {
            if (@field(components, field.name)) |value| {
                gs.ecs.addComponent(entity_id, value) catch {
                    gs.ecs.undoSpawn(entity_id);
                    return null;
                };
            }
        } else {
            gs.ecs.addComponent(entity_id, @field(components, field.name)) catch {
                gs.ecs.undoSpawn(entity_id);
                return null;
            };
        }
    }
    return entity_id;
}

pub fn spawnGameController(gs: *game.Session, params: struct {
    num_players: u32,
}) ?gbe.EntityId {
    return spawnWithComponents(gs, struct {
        @"0": c.GameController,
        @"1": c.VoiceAccelerate,
        @"2": c.VoiceWaveBegin,
    }{
        .@"0" = c.GameController{
            .monster_count = 0,
            .enemy_speed_level = 0,
            .enemy_speed_timer = constants.enemy_speed_ticks,
            .wave_number = 0,
            .next_wave_timer = constants.duration60(90),
            .next_pickup_timer = constants.duration60(15 * 60),
            .freeze_monsters_timer = 0,
            .extra_lives_spawned = 0,
            .wave_message = null,
            .wave_message_timer = 0,
            .num_players_remaining = params.num_players,
        },
        .@"1" = c.VoiceAccelerate{
            .params = null,
        },
        .@"2" = c.VoiceWaveBegin{
            .params = null,
        },
    });
}

pub fn spawnPlayerController(gs: *game.Session, params: struct {
    player_number: u32,
}) ?gbe.EntityId {
    return spawnWithComponents(gs, struct {
        @"0": c.PlayerController,
    }{
        .@"0" = c.PlayerController{
            .player_number = params.player_number,
            .player_id = null,
            .lives = constants.player_num_lives,
            .score = 0,
            .respawn_timer = 1,
        },
    });
}

pub fn spawnPlayer(gs: *game.Session, params: struct {
    player_number: u32,
    player_controller_id: gbe.EntityId,
    pos: math.Vec2,
}) ?gbe.EntityId {
    return spawnWithComponents(gs, struct {
        @"0": c.Transform,
        @"1": c.PhysObject,
        @"2": c.Creature,
        @"3": c.Player,
        @"4": c.VoiceCoin,
        @"5": c.VoiceLaser,
        @"6": c.VoicePowerUp,
        @"7": c.VoiceSampler,
    }{
        .@"0" = c.Transform{
            .pos = math.vec2(params.pos.x, params.pos.y + levels.subpixels_per_tile),
        },
        .@"1" = c.PhysObject{
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
        },
        .@"2" = c.Creature{
            .invulnerability_timer = constants.invulnerability_time,
            .hit_points = 1,
            .flinch_timer = 0,
            .god_mode = false,
        },
        .@"3" = c.Player{
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
        },
        .@"4" = c.VoiceCoin{ .params = null },
        .@"5" = c.VoiceLaser{ .params = null },
        .@"6" = c.VoicePowerUp{ .params = null },
        .@"7" = c.VoiceSampler{ .sample = null },
    });
}

pub fn spawnPlayerCorpse(gs: *game.Session, params: struct {
    pos: math.Vec2,
}) ?gbe.EntityId {
    return spawnWithComponents(gs, struct {
        @"0": c.Transform,
        @"1": c.SimpleGraphic,
    }{
        .@"0" = c.Transform{
            .pos = params.pos,
        },
        .@"1" = c.SimpleGraphic{
            .graphic = .man_dying6,
            .z_index = constants.z_index_corpse,
            .directional = false,
        },
    });
}

pub fn spawnMonster(gs: *game.Session, params: struct {
    wave_number: u32,
    monster_type: constants.MonsterType,
    pos: math.Vec2,
    has_coin: bool,
}) ?gbe.EntityId {
    const monster_values = constants.getMonsterValues(params.monster_type);

    const can_shoot = if (monster_values.first_shooting_level) |first_level|
        params.wave_number >= first_level
    else
        false;

    return spawnWithComponents(gs, struct {
        @"0": c.Transform,
        @"1": c.PhysObject,
        @"2": c.Creature,
        @"3": c.Monster,
        @"4": ?c.VoiceLaser,
    }{
        .@"0" = c.Transform{
            .pos = params.pos,
        },
        .@"1" = c.PhysObject{
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
        },
        .@"2" = c.Creature{
            .invulnerability_timer = 0,
            .hit_points = 999, // invulnerable while spawning
            .flinch_timer = 0,
            .god_mode = false,
        },
        .@"3" = c.Monster{
            .monster_type = params.monster_type,
            .spawning_timer = constants.monster_spawn_time,
            .full_hit_points = monster_values.hit_points,
            .personality = if (params.monster_type == .juggernaut)
                c.Monster.Personality.chase
            else if (gs.prng.random.boolean())
                c.Monster.Personality.chase
            else
                c.Monster.Personality.wander,
            .can_shoot = can_shoot,
            .next_attack_timer = if (can_shoot or monster_values.can_drop_webs)
                constants.duration60(gs.prng.random.intRangeLessThan(u31, 75, 400))
            else
                0,
            .has_coin = params.has_coin,
        },
        .@"4" = if (can_shoot)
            c.VoiceLaser{
                .params = null,
            }
        else
            null,
    });
}

pub fn spawnWeb(gs: *game.Session, params: struct {
    pos: math.Vec2,
}) ?gbe.EntityId {
    return spawnWithComponents(gs, struct {
        @"0": c.Transform,
        @"1": c.PhysObject,
        @"2": c.Web,
        @"3": c.Creature,
        @"4": c.VoiceSampler,
    }{
        .@"0" = c.Transform{
            .pos = params.pos,
        },
        .@"1" = c.PhysObject{
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
        },
        .@"2" = c.Web{},
        .@"3" = c.Creature{
            .invulnerability_timer = 0,
            .hit_points = 3,
            .flinch_timer = 0,
            .god_mode = false,
        },
        .@"4" = c.VoiceSampler{
            .sample = .drop_web,
        },
    });
}

pub fn spawnBullet(gs: *game.Session, params: struct {
    inflictor_player_controller_id: ?gbe.EntityId,
    owner_id: gbe.EntityId,
    pos: math.Vec2,
    facing: math.Direction,
    bullet_type: c.Bullet.Type,
    cluster_size: u32,
    friendly_fire: bool,
}) ?gbe.EntityId {
    return spawnWithComponents(gs, struct {
        @"0": c.Transform,
        @"1": c.PhysObject,
        @"2": c.Bullet,
        @"3": c.SimpleGraphic,
    }{
        .@"0" = c.Transform{
            .pos = params.pos,
        },
        .@"1" = c.PhysObject{
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
                .monster_bullet => c.PhysObject.FLAG_MONSTER | c.PhysObject.FLAG_WEB,
                // player bullets ignore only the player that shot it (via
                // `owner_id`), unless friendly fire is disabled.
                // see also src/oxid/set_friendly_fire.zig, where this value
                // is changed (called when user toggles friendly fire in the
                // menu)
                .player_bullet => if (!params.friendly_fire) c.PhysObject.FLAG_PLAYER else 0,
            },
            .internal = undefined,
        },
        .@"2" = c.Bullet{
            .bullet_type = params.bullet_type,
            .inflictor_player_controller_id = params.inflictor_player_controller_id,
            .damage = params.cluster_size,
            .line_of_fire = null,
        },
        .@"3" = c.SimpleGraphic{
            .graphic = switch (params.bullet_type) {
                .monster_bullet => .mon_bullet,
                .player_bullet => @as(graphics.Graphic, switch (params.cluster_size) {
                    1 => .pla_bullet,
                    2 => .pla_bullet2,
                    else => .pla_bullet3,
                }),
            },
            .z_index = constants.z_index_bullet,
            .directional = true,
        },
    });
}

pub fn spawnAnimation(gs: *game.Session, params: struct {
    pos: math.Vec2,
    simple_anim: graphics.SimpleAnim,
    z_index: u32,
}) ?gbe.EntityId {
    return spawnWithComponents(gs, struct {
        @"0": c.Transform,
        @"1": c.Animation,
    }{
        .@"0" = c.Transform{
            .pos = params.pos,
        },
        .@"1" = c.Animation{
            .simple_anim = params.simple_anim,
            .frame_index = 0,
            .frame_timer = graphics.getSimpleAnim(params.simple_anim).ticks_per_frame,
            .z_index = params.z_index,
        },
    });
}

pub fn spawnPickup(gs: *game.Session, params: struct {
    pos: math.Vec2,
    pickup_type: constants.PickupType,
}) ?gbe.EntityId {
    const pickup_values = constants.getPickupValues(params.pickup_type);

    return spawnWithComponents(gs, struct {
        @"0": c.Transform,
        @"1": c.SimpleGraphic,
        @"2": c.PhysObject,
        @"3": c.Pickup,
        @"4": c.RemoveTimer,
    }{
        .@"0" = c.Transform{
            .pos = params.pos,
        },
        .@"1" = c.SimpleGraphic{
            .graphic = switch (params.pickup_type) {
                .power_up => .power_up,
                .speed_up => .speed_up,
                .life_up => .life_up,
                .coin => .coin,
            },
            .z_index = constants.z_index_pickup,
            .directional = false,
        },
        .@"2" = c.PhysObject{
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
        },
        .@"3" = c.Pickup{
            .pickup_type = params.pickup_type,
        },
        .@"4" = c.RemoveTimer{
            .timer = pickup_values.lifetime,
        },
    });
}

pub fn spawnSparks(gs: *game.Session, params: struct {
    pos: math.Vec2,
    impact_sound: bool,
}) ?gbe.EntityId {
    return spawnWithComponents(gs, struct {
        @"0": c.Transform,
        @"1": c.Animation,
        @"2": ?c.VoiceSampler,
    }{
        .@"0" = c.Transform{
            .pos = params.pos,
        },
        .@"1" = c.Animation{
            .simple_anim = .pla_sparks,
            .frame_index = 0,
            .frame_timer = graphics.getSimpleAnim(.pla_sparks).ticks_per_frame,
            .z_index = constants.z_index_sparks,
        },
        .@"2" = if (params.impact_sound)
            c.VoiceSampler{
                .sample = .monster_impact,
            }
        else
            null,
    });
}

pub fn spawnExplosion(gs: *game.Session, params: struct {
    pos: math.Vec2,
}) ?gbe.EntityId {
    return spawnWithComponents(gs, struct {
        @"0": c.Transform,
        @"1": c.Animation,
        @"2": c.VoiceExplosion,
    }{
        .@"0" = c.Transform{
            .pos = params.pos,
        },
        .@"1" = c.Animation{
            .simple_anim = .explosion,
            .frame_index = 0,
            .frame_timer = graphics.getSimpleAnim(.explosion).ticks_per_frame,
            .z_index = constants.z_index_explosion,
        },
        .@"2" = c.VoiceExplosion{
            .params = .{},
        },
    });
}

fn event(comptime T: type) fn (gs: *game.Session, body: T) void {
    return struct {
        fn spawn(gs: *game.Session, body: T) void {
            const entity_id = gs.ecs.spawn();
            gs.ecs.addComponent(entity_id, body) catch |err| {
                // TODO warn?
                gs.ecs.undoSpawn(entity_id);
            };
        }
    }.spawn;
}

pub const spawnEventAwardLife = event(c.EventAwardLife);
pub const spawnEventAwardPoints = event(c.EventAwardPoints);
pub const spawnEventCollide = event(c.EventCollide);
pub const spawnEventConferBonus = event(c.EventConferBonus);
pub const spawnEventDraw = event(c.EventDraw);
pub const spawnEventDrawBox = event(c.EventDrawBox);
pub const spawnEventGameInput = event(c.EventGameInput);
pub const spawnEventGameOver = event(c.EventGameOver);
pub const spawnEventMonsterDied = event(c.EventMonsterDied);
pub const spawnEventPlayerDied = event(c.EventPlayerDied);
pub const spawnEventPlayerOutOfLives = event(c.EventPlayerOutOfLives);
pub const spawnEventShowMessage = event(c.EventShowMessage);
pub const spawnEventTakeDamage = event(c.EventTakeDamage);
