pub const MonsterType = enum{
  Spider,
  FastBug,
  Squid,
};

pub const MonsterValues = struct{
  hit_points: u32,
  move_speed: u31,
  kill_points: u32,
  can_shoot: bool,
};

pub const Wave = struct{
  spiders: u32,
  fastbugs: u32,
  squids: u32,
  speed: u31,
  coins: u32,
};
