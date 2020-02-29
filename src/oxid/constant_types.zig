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

pub const Wave = struct {
    spiders: u32,
    knights: u32,
    fastbugs: u32,
    squids: u32,
    juggernauts: u32,
    speed: u31,
    message: ?[]const u8,
};
