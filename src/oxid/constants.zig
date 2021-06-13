// the game updates this many times per second. you should be able to change
// this value to speed up / slow down the entire game.
// (high values may cause the speed60/duration60 function results to round down
// to zero though, which is never good)
pub const ticks_per_second = 60;

pub fn speed60(v: u31) u31 {
    return v * 60 / ticks_per_second;
}

pub fn duration60(v: u31) u31 {
    return ticks_per_second * v / 60;
}

pub const num_high_scores = 10;
pub const num_demo_index_entries = 10;

pub const enemy_speed_ticks = duration60(20 * 60); // every 20 seconds, increase monster speed
pub const max_enemy_speed_level = 4;
pub const pickup_spawn_time = duration60(60 * 60); // spawn a new pickup every 60 seconds
pub const next_wave_time = duration60(45); // next wave will begin 0.75 seconds after the last monster dies
pub const monster_spawn_time = duration60(90); // monsters are in spawning state for 1.5 seconds
pub const monster_freeze_time = duration60(4 * 60); // monsters freeze for 4 seconds when player dies

// if you push into a wall but there is corner within this distance, move
// around the corner.
pub const player_slip_threshold = 12 * 16; // FIXME - use screen space

pub const player_death_anim_time: u32 = duration60(90); // 1.5 seconds
pub const player_respawn_time: u32 = duration60(150); // 2.5 seconds
pub const player_spawn_arise_speed: u31 = speed60(8); // how fast the player "arises" when spawning
pub const player_num_lives: u32 = 3;

pub const max_oxygen = 10;
pub const oxygen_per_coin = 1;
pub const oxygen_per_wave = 10;
pub const ticks_per_oxygen_spent = 180; // player loses 1 point every 3 seconds
// although every time you pick up a coin the tick timer resets, so actually
// you lose one point every 3-6 seconds

pub const PlayerColor = enum {
    yellow,
    green,
};

pub const MonsterType = enum {
    spider,
    knight,
    fast_bug,
    squid,
    juggernaut,
};

pub const MonsterValues = struct {
    hit_points: u32,
    move_speed: [4]u31,
    kill_points: u32,
    first_shooting_level: ?u32,
    can_drop_webs: bool,
    persistent: bool,
};

pub fn getMonsterValues(monster_type: MonsterType) MonsterValues {
    return switch (monster_type) {
        .spider => .{
            .hit_points = 1,
            .move_speed = .{
                speed60(6),
                speed60(9),
                speed60(12),
                speed60(15),
            },
            .kill_points = 10,
            .first_shooting_level = null,
            .can_drop_webs = false,
            .persistent = false,
        },
        .knight => .{
            .hit_points = 2,
            .move_speed = .{
                speed60(6),
                speed60(9),
                speed60(12),
                speed60(15),
            },
            .kill_points = 20,
            .first_shooting_level = 9,
            .can_drop_webs = false,
            .persistent = false,
        },
        .fast_bug => .{
            .hit_points = 1,
            .move_speed = .{
                speed60(12),
                speed60(16),
                speed60(20),
                speed60(24),
            },
            .kill_points = 10,
            .first_shooting_level = null,
            .can_drop_webs = false,
            .persistent = false,
        },
        .squid => .{
            .hit_points = 5,
            .move_speed = .{
                speed60(3),
                speed60(4),
                speed60(6),
                speed60(8),
            },
            .kill_points = 80,
            .first_shooting_level = null,
            .can_drop_webs = true,
            .persistent = false,
        },
        .juggernaut => .{
            .hit_points = 9999,
            .move_speed = .{
                speed60(4),
                speed60(4),
                speed60(4),
                speed60(4),
            },
            .kill_points = 0,
            .first_shooting_level = null,
            .can_drop_webs = false,
            .persistent = true,
        },
    };
}

pub const PickupType = enum {
    coin,
    life_up,
    power_up,
    speed_up,
};

pub const PickupValues = struct {
    lifetime: u32,
    get_points: u32,
    message: ?[]const u8,
};

pub fn getPickupValues(pickup_type: PickupType) PickupValues {
    return switch (pickup_type) {
        .coin => .{
            .lifetime = duration60(6 * 60),
            .get_points = 20,
            .message = null,
        },
        .life_up => .{
            .lifetime = duration60(15 * 60),
            .get_points = 0,
            .message = "Life up!",
        },
        .power_up => .{
            .lifetime = duration60(12 * 60),
            .get_points = 0,
            .message = "Power up!",
        },
        .speed_up => .{
            .lifetime = duration60(12 * 60),
            .get_points = 0,
            .message = "Speed up!",
        },
    };
}

pub const invulnerability_time: u32 = duration60(2 * 60);

pub const player_bullet_speed: u31 = speed60(64);
pub const monster_bullet_speed: u31 = speed60(20);

pub const player_max_bullets: usize = 2;
pub const player_move_speed = [3]u31{
    speed60(16),
    speed60(20),
    speed60(24),
};

pub const z_index_sparks: u32 = 120;
pub const z_index_player: u32 = 100;
pub const z_index_explosion: u32 = 81;
pub const z_index_enemy: u32 = 80;
pub const z_index_bullet: u32 = 50;
pub const z_index_pickup: u32 = 30;
pub const z_index_web: u32 = 25;
pub const z_index_corpse: u32 = 20;

pub const extra_life_score_thresholds = [_]u32{
    1500,
    3000,
    6000,
    10000,
    15000,
    20000,
    25000,
};
