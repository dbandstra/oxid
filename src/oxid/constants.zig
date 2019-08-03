const ConstantTypes = @import("constant_types.zig");
const MonsterType = ConstantTypes.MonsterType;
const MonsterValues = ConstantTypes.MonsterValues;
const PickupType = ConstantTypes.PickupType;
const PickupValues = ConstantTypes.PickupValues;
const Wave = ConstantTypes.Wave;

pub const num_high_scores = 10;

pub const enemy_speed_ticks = 20*60; // every 20 seconds, increase monster speed
pub const max_enemy_speed_level = 4;
pub const pickup_spawn_time = 60*60; // spawn a new pickup every 60 seconds
pub const next_wave_time = 45; // next wave will begin 0.75 seconds after the last monster dies
pub const monster_spawn_time = 90; // monsters are in spawning state for 1.5 seconds
pub const monster_freeze_time = 4*60; // monsters freeze for 3 seconds when player dies

// if you push into a wall but there is corner within this distance, move
// around the corner.
pub const player_slip_threshold = 12*16; // FIXME - use screen space

pub const player_death_anim_time: u32 = 90; // 1.5 seconds
pub const player_respawn_time: u32 = 150; // 2.5 seconds
pub const player_num_lives: u32 = 3;

pub fn getMonsterValues(monster_type: MonsterType) MonsterValues {
    return switch (monster_type) {
        .Spider => MonsterValues {
            .hit_points = 1,
            .move_speed = [4]u31{ 6, 9, 12, 15 },
            .kill_points = 10,
            .first_shooting_level = null,
            .can_drop_webs = false,
            .persistent = false,
        },
        .Knight => MonsterValues {
            .hit_points = 2,
            .move_speed = [4]u31{ 6, 9, 12, 15 },
            .kill_points = 20,
            .first_shooting_level = 9,
            .can_drop_webs = false,
            .persistent = false,
        },
        .FastBug => MonsterValues {
            .hit_points = 1,
            .move_speed = [4]u31{ 12, 16, 20, 24 },
            .kill_points = 10,
            .first_shooting_level = null,
            .can_drop_webs = false,
            .persistent = false,
        },
        .Squid => MonsterValues {
            .hit_points = 5,
            .move_speed = [4]u31{ 3, 4, 6, 8 },
            .kill_points = 80,
            .first_shooting_level = null,
            .can_drop_webs = true,
            .persistent = false,
        },
        .Juggernaut => MonsterValues {
            .hit_points = 9999,
            .move_speed = [4]u31{ 4, 4, 4, 4 },
            .kill_points = 0,
            .first_shooting_level = null,
            .can_drop_webs = false,
            .persistent = true,
        },
    };
}

pub fn getPickupValues(pickup_type: PickupType) PickupValues {
    return switch (pickup_type) {
        .Coin => PickupValues {
            .lifetime = 6*60,
            .get_points = 20,
            .message = null,
        },
        .LifeUp => PickupValues {
            .lifetime = 15*60,
            .get_points = 0,
            .message = "Life up!",
        },
        .PowerUp => PickupValues {
            .lifetime = 12*60,
            .get_points = 0,
            .message = "Power up!",
        },
        .SpeedUp => PickupValues {
            .lifetime = 12*60,
            .get_points = 0,
            .message = "Speed up!",
        },
    };
}

pub const invulnerability_time: u32 = 2*60;

pub const player_bullet_speed: u31 = 64;
pub const monster_bullet_speed: u31 = 20;

pub const player_max_bullets: usize = 2;
pub const player_move_speed = [3]u31{ 16, 20, 24 };

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
