pub const GRAPHICS_FILENAME = "../../assets/mytiles.pcx";
pub const TRANSPARENT_COLOR_INDEX = 27;

pub const Graphic = enum{
  Pit,
  PlaBullet,
  PlaBullet2,
  PlaBullet3,
  PlaSpark1,
  PlaSpark2,
  MonBullet,
  MonSpark1,
  MonSpark2,
  Floor,
  Man1,
  Man2,
  ManDying1,
  ManDying2,
  ManDying3,
  ManDying4,
  ManDying5,
  ManDying6,
  Wall,
  Wall2,
  Spider1,
  Spider2,
  Explode1,
  Explode2,
  Explode3,
  Explode4,
  Spawn1,
  Spawn2,
  Squid1,
  Squid2,
  PowerUp,
  SpeedUp,
  LifeUp,
};

pub const GraphicConfig = struct{
  tx: u32,
  ty: u32,
};

pub fn getGraphicConfig(graphic: Graphic) GraphicConfig {
  return switch (graphic) {
    Graphic.Pit        => GraphicConfig{ .tx = 1, .ty = 0 },
    Graphic.Floor      => GraphicConfig{ .tx = 2, .ty = 0 },
    Graphic.Wall,
    Graphic.Wall2      => GraphicConfig{ .tx = 3, .ty = 0 },
    Graphic.PlaBullet  => GraphicConfig{ .tx = 2, .ty = 1 },
    Graphic.PlaBullet2 => GraphicConfig{ .tx = 3, .ty = 1 },
    Graphic.PlaBullet3 => GraphicConfig{ .tx = 4, .ty = 1 },
    Graphic.PlaSpark1  => GraphicConfig{ .tx = 1, .ty = 1 },
    Graphic.PlaSpark2  => GraphicConfig{ .tx = 0, .ty = 1 },
    Graphic.MonBullet  => GraphicConfig{ .tx = 2, .ty = 3 },
    Graphic.MonSpark1  => GraphicConfig{ .tx = 1, .ty = 3 },
    Graphic.MonSpark2  => GraphicConfig{ .tx = 0, .ty = 3 },
    Graphic.Man1       => GraphicConfig{ .tx = 6, .ty = 1 },
    Graphic.Man2       => GraphicConfig{ .tx = 7, .ty = 1 },
    Graphic.ManDying1  => GraphicConfig{ .tx = 0, .ty = 4 },
    Graphic.ManDying2  => GraphicConfig{ .tx = 1, .ty = 4 },
    Graphic.ManDying3  => GraphicConfig{ .tx = 2, .ty = 4 },
    Graphic.ManDying4  => GraphicConfig{ .tx = 3, .ty = 4 },
    Graphic.ManDying5  => GraphicConfig{ .tx = 4, .ty = 4 },
    Graphic.ManDying6  => GraphicConfig{ .tx = 5, .ty = 4 },
    Graphic.Spider1    => GraphicConfig{ .tx = 3, .ty = 2 },
    Graphic.Spider2    => GraphicConfig{ .tx = 4, .ty = 2 },
    Graphic.Explode1   => GraphicConfig{ .tx = 0, .ty = 5 },
    Graphic.Explode2   => GraphicConfig{ .tx = 1, .ty = 5 },
    Graphic.Explode3   => GraphicConfig{ .tx = 2, .ty = 5 },
    Graphic.Explode4   => GraphicConfig{ .tx = 3, .ty = 5 },
    Graphic.Spawn1     => GraphicConfig{ .tx = 2, .ty = 2 },
    Graphic.Spawn2     => GraphicConfig{ .tx = 1, .ty = 2 },
    Graphic.Squid1     => GraphicConfig{ .tx = 3, .ty = 3 },
    Graphic.Squid2     => GraphicConfig{ .tx = 4, .ty = 3 },
    Graphic.LifeUp     => GraphicConfig{ .tx = 4, .ty = 5 },
    Graphic.PowerUp    => GraphicConfig{ .tx = 6, .ty = 5 },
    Graphic.SpeedUp    => GraphicConfig{ .tx = 5, .ty = 5 },
  };
}

pub const SimpleAnim = enum{
  PlaSparks,
  MonSparks,
  Explosion,
};

pub const SimpleAnimConfig = struct{
  frames: []const Graphic,
  ticks_per_frame: u32,
};

pub fn getSimpleAnim(simpleAnim: SimpleAnim) SimpleAnimConfig {
  return switch (simpleAnim) {
    SimpleAnim.PlaSparks => SimpleAnimConfig{
      .frames = ([2]Graphic{
        Graphic.PlaSpark1,
        Graphic.PlaSpark2,
      })[0..],
      .ticks_per_frame = 4,
    },
    SimpleAnim.MonSparks => SimpleAnimConfig{
      .frames = ([2]Graphic{
        Graphic.MonSpark1,
        Graphic.MonSpark2,
      })[0..],
      .ticks_per_frame = 4,
    },
    SimpleAnim.Explosion => SimpleAnimConfig{
      .frames = ([4]Graphic{
        Graphic.Explode1,
        Graphic.Explode2,
        Graphic.Explode3,
        Graphic.Explode4,
      })[0..],
      .ticks_per_frame = 4,
    }
  };
}
