const zang = @import("zang");
const gbe = @import("gbe");
const drawing = @import("../common/drawing.zig");
const math = @import("../common/math.zig");
const constants = @import("constants.zig");
const graphics = @import("graphics.zig");
const commands = @import("commands.zig");
const audio = @import("audio.zig");

pub const GameController = struct {
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
    player1_controller_id: gbe.EntityID,
    player2_controller_id: ?gbe.EntityID,
    // ticker: increments by 1 every frame, and wraps around. used for making
    // things blink on the HUD
    ticker: u32,
};

pub const PlayerController = struct {
    player_id: ?gbe.EntityID,
    color: constants.PlayerColor,
    lives: u32,
    score: u32,
    respawn_timer: u32,
};

pub const Transform = struct {
    pos: math.Vec2,
};

pub const PhysObject = struct {
    pub const FLAG_BULLET: u32 = 1;
    pub const FLAG_MONSTER: u32 = 2;
    pub const FLAG_WEB: u32 = 4;
    pub const FLAG_PLAYER: u32 = 8;

    // `illusory`: if true, this object is non-solid, but still causes 'collide'
    // events when overlapped
    illusory: bool,

    // bounding boxes are relative to transform position. the dimensions of the
    // box will be (maxs - mins + 1).
    // `world_bbox`: the bbox used to collide with the level.
    world_bbox: math.Box,

    // `entity_bbox`: the bbox used to collide with other entities. this may be a
    // bit smaller than the world bbox
    entity_bbox: math.Box,

    // `facing`: direction of movement (meaningless if `speed` is 0)
    facing: math.Direction,

    // `speed`: velocity along the `facing` direction (diagonal motion is not
    // supported). this is measured in subpixels per tick
    speed: u31,

    // `push_dir`: if set, the object will try to redirect to go this way if
    // there is no obstruction.
    push_dir: ?math.Direction,

    // `owner_id`: collision will be skipped between an object and its owner.
    // e.g. a bullet is owned by the person who shot it
    owner_id: ?gbe.EntityID,

    // `flags` used with reference to `ignore_flags` (see below)
    flags: u32,

    // `ignore_flags`: skip collision with (i.e., pass through) entities who have
    // any of these flags set in `flags`
    ignore_flags: u32,

    // internal fields used by physics step
    internal: struct {
        move_bbox: math.Box,
        group_index: usize,
    },
};

pub const Creature = struct {
    invulnerability_timer: u32,
    hit_points: u32,
    flinch_timer: u32,
};

pub const Player = struct {
    pub const AttackLevel = enum { one, two, three };
    pub const SpeedLevel = enum { one, two, three };

    player_controller_id: gbe.EntityID,
    color: constants.PlayerColor,
    trigger_released: bool,
    bullets: [constants.player_max_bullets]?gbe.EntityID,
    oxygen: u32,
    oxygen_timer: u32,
    attack_level: AttackLevel,
    speed_level: SpeedLevel,
    spawn_anim_y_remaining: u31,
    dying_timer: u32,
    last_pickup: ?constants.PickupType,
    line_of_fire: ?math.Box,
    in_left: bool,
    in_right: bool,
    in_up: bool,
    in_down: bool,
    in_shoot: bool,
};

pub const Monster = struct {
    pub const Personality = enum {
        chase,
        wander,
    };

    monster_type: constants.MonsterType,
    spawning_timer: u32,
    full_hit_points: u32,
    personality: Personality,
    can_shoot: bool,
    next_attack_timer: u32,
    has_coin: bool,
};

pub const Web = struct {};

pub const Bullet = struct {
    pub const Type = enum {
        monster_bullet,
        player_bullet,
    };

    bullet_type: Type,
    inflictor_player_controller_id: ?gbe.EntityID,
    damage: u32,
    line_of_fire: ?math.Box,
};

pub const SimpleGraphic = struct {
    graphic: graphics.Graphic,
    z_index: u32,
    directional: bool,
};

pub const Animation = struct {
    simple_anim: graphics.SimpleAnim,
    frame_index: u32,
    frame_timer: u32,
    z_index: u32,
};

pub const Pickup = struct {
    pickup_type: constants.PickupType,
};

pub const RemoveTimer = struct {
    timer: u32,
};

pub const EventAwardLife = struct {
    player_controller_id: gbe.EntityID,
};

pub const EventAwardPoints = struct {
    player_controller_id: gbe.EntityID,
    points: u32,
};

pub const EventCollide = struct {
    pub const CollisionType = enum {
        // the two entities overlap
        overlap,

        // self ran into other, or they both ran into each other
        propelled,

        // other ran into self while self was either motionless or moving in a different direction
        hit_by_other,
    };

    self_id: gbe.EntityID,
    other_id: ?gbe.EntityID, // null = wall
    collision_type: CollisionType,
};

pub const EventConferBonus = struct {
    recipient_id: gbe.EntityID,
    pickup_type: constants.PickupType,
};

pub const EventDraw = struct {
    pos: math.Vec2,
    graphic: graphics.Graphic,
    transform: drawing.Transform,
    z_index: u32,
    alpha: u8,
};

pub const EventDrawBox = struct {
    box: math.Box,
    color: drawing.Color,
};

pub const EventGameInput = struct {
    player_controller_id: gbe.EntityID,
    command: commands.GameCommand,
    down: bool,
};

pub const EventGameOver = struct {};

pub const EventMonsterDied = struct {};

pub const EventPlaySound = struct {
    params: audio.SoundParams,
};

pub const EventPlayerDied = struct {
    player_controller_id: gbe.EntityID,
};

pub const EventRestoreOxygen = struct {};

pub const EventShowMessage = struct {
    message: []const u8,
};

pub const EventTakeDamage = struct {
    inflictor_player_controller_id: ?gbe.EntityID,
    self_id: gbe.EntityID,
    amount: u32,
};
