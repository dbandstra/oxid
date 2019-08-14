const zang = @import("zang");
const gbe = @import("gbe");
const Math = @import("../common/math.zig");
const Key = @import("../common/key.zig").Key;
const Draw = @import("../common/draw.zig");
const ConstantTypes = @import("constant_types.zig");
const Constants = @import("constants.zig");
const SimpleAnim = @import("graphics.zig").SimpleAnim;
const Graphic = @import("graphics.zig").Graphic;
const input = @import("input.zig");
const audio = @import("audio.zig");
const menus = @import("menus.zig");

pub const MainController = struct {
    pub const GameRunningState = struct {
        render_move_boxes: bool,
    };
    pub const Menu = union(enum) {
        MainMenu: menus.MainMenu,
        InGameMenu: menus.InGameMenu,
        ReallyEndGameMenu,
        OptionsMenu: menus.OptionsMenu,
        KeyBindingsMenu: menus.KeyBindingsMenu,
        HighScoresMenu: menus.HighScoresMenu,
    };
    pub const menu_stack_size = 3;

    is_fullscreen: bool,
    is_muted: bool,
    high_scores: [Constants.num_high_scores]u32,
    new_high_score: bool,
    game_running_state: ?GameRunningState,
    menu_stack_array: [menu_stack_size]Menu,
    menu_stack_len: usize,
};

pub const Bullet = struct {
    inflictor_player_controller_id: ?gbe.EntityId,
    damage: u32,
    line_of_fire: ?Math.BoundingBox,
};

pub const Creature = struct {
    invulnerability_timer: u32,
    hit_points: u32,
    flinch_timer: u32,
    god_mode: bool,
};

pub const Monster = struct {
    pub const Personality = enum {
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

pub const Web = struct {};

// maybe this should just be an object inside MainController?
// combine with GameRunningState
pub const GameController = struct {
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

pub const PlayerController = struct {
    player_id: ?gbe.EntityId,
    lives: u32,
    score: u32,
    respawn_timer: u32,
};

pub const Animation = struct {
    simple_anim: SimpleAnim,
    frame_index: u32,
    frame_timer: u32,
    z_index: u32,
};

pub const RemoveTimer = struct {
    timer: u32,
};

pub const SimpleGraphic = struct {
    graphic: Graphic,
    z_index: u32,
    directional: bool,
};

pub const PhysObject = struct {
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
    owner_id: gbe.EntityId,

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

pub const PhysObjectInternal = struct {
    move_bbox: Math.BoundingBox,
    group_index: usize,
};

pub const Pickup = struct {
    pickup_type: ConstantTypes.PickupType,
    get_points: u32,
    message: ?[]const u8,
};

pub const Player = struct {
    pub const AttackLevel = enum {
        One,
        Two,
        Three,
    };

    pub const SpeedLevel = enum {
        One,
        Two,
        Three,
    };

    player_controller_id: gbe.EntityId,
    trigger_released: bool,
    bullets: [Constants.player_max_bullets]?gbe.EntityId,
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

pub const Transform = struct {
    pos: Math.Vec2,
};

pub const EventAwardLife = struct {
    player_controller_id: gbe.EntityId,
};

pub const EventAwardPoints = struct {
    player_controller_id: gbe.EntityId,
    points: u32,
};

pub const EventCollide = struct {
    self_id: gbe.EntityId,
    other_id: gbe.EntityId, // 0 = wall

    // `propelled`: if true, `self` ran into `other` (or they both ran into each
    // other). if false, `other` ran into `self` while `self` was either
    // motionless or moving in another direction.
    propelled: bool,
};

pub const EventConferBonus = struct {
    recipient_id: gbe.EntityId,
    pickup_type: ConstantTypes.PickupType,
};

pub const EventDraw = struct {
    pos: Math.Vec2,
    graphic: Graphic,
    transform: Draw.Transform,
    z_index: u32,
};

pub const EventDrawBox = struct {
    box: Math.BoundingBox,
    color: Draw.Color,
};

pub const EventRawInput = struct {
    game_command: ?input.GameCommand,
    menu_command: ?input.MenuCommand,
    key: Key,
    down: bool,
};

pub const EventGameInput = struct {
    command: input.GameCommand,
    down: bool,
};

pub const EventMenuInput = struct {
    command: ?input.MenuCommand,
    key: Key, // used for the key binding menu
    down: bool,
};

pub const EventMonsterDied = struct {};

pub const EventPlayerDied = struct {
    player_controller_id: gbe.EntityId,
};

pub const EventPlayerOutOfLives = struct {
    player_controller_id: gbe.EntityId,
};

pub const EventPostScore = struct {
    score: u32,
};

pub const EventShowMessage = struct {
    message: []const u8,
};

pub const BindGameCommand = struct {
    command: input.GameCommand,
    key: ?Key,
};

pub const EventSystemCommand = union(enum) {
    ToggleMute,
    ToggleFullscreen,
    BindGameCommand: BindGameCommand,
    SaveHighScores: [Constants.num_high_scores]u32,
    Quit,
};

pub const EventTakeDamage = struct {
    inflictor_player_controller_id: ?gbe.EntityId,
    self_id: gbe.EntityId,
    amount: u32,
};

pub const Voice = struct {
    pub fn Wrapper(comptime T: type, comptime P: type) type {
        return struct {
            pub const ModuleType = T;
            pub const NoteParams = P;

            // `initial_params`: set when the Voice entity is spawned. this will be
            // fed into the impulse queue by the sound middleware at the end of the
            // frame. (it can't be done when spawning the entity because it requires
            // a lock on the audio thread and a calculated impulse frame.)
            initial_params: ?NoteParams,
            // `initial_sample`: this is a hack that is used instead of
            // initial_params for sample voices. the game code doesn't have access to
            // the wav file data that is needed to create the params for the sampler.
            initial_sample: ?audio.Sample,
            iq: zang.Notes(NoteParams).ImpulseQueue,
            module: T,
            trigger: zang.Trigger(NoteParams),
        };
    }

    pub const WrapperU = union(enum) {
        Accelerate: Wrapper(audio.AccelerateVoice, audio.AccelerateVoice.NoteParams),
        Coin: Wrapper(audio.CoinVoice, audio.CoinVoice.NoteParams),
        Explosion: Wrapper(audio.ExplosionVoice, audio.ExplosionVoice.NoteParams),
        Laser: Wrapper(audio.LaserVoice, audio.LaserVoice.NoteParams),
        MenuBackoff: Wrapper(audio.MenuBackoffVoice, audio.MenuBackoffVoice.NoteParams),
        MenuBlip: Wrapper(audio.MenuBlipVoice, audio.MenuBlipVoice.NoteParams),
        MenuDing: Wrapper(audio.MenuDingVoice, audio.MenuDingVoice.NoteParams),
        Sample: Wrapper(zang.Sampler, audio.SamplerNoteParams),
        WaveBegin: Wrapper(audio.WaveBeginVoice, audio.WaveBeginVoice.NoteParams),
    };

    wrapper: WrapperU,
};
