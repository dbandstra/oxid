pub const MonsterType = enum{
  Spider,
  Knight,
  FastBug,
  Squid,
  Juggernaut,
};

pub const MonsterValues = struct{
  hit_points: u32,
  move_speed: [4]u31,
  kill_points: u32,
  can_shoot: bool,
};

pub const PickupType = enum{
  Coin,
  LifeUp,
  PowerUp,
  SpeedUp,
};

pub const PickupValues = struct{
  lifetime: u32,
  get_points: u32,
};

pub const Wave = struct{
  spiders: u32,
  knights: u32,
  fastbugs: u32,
  squids: u32,
  juggernauts: u32,
  speed: u31,
};
