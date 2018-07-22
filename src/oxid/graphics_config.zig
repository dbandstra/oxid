pub const GRAPHICS_FILENAME = "../../assets/mytiles.pcx";
pub const TRANSPARENT_COLOR_INDEX = 12;

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
};

pub const GraphicConfig = struct{
  tx: u32,
  ty: u32,
  fliph: bool,
};

pub fn getGraphicConfig(graphic: Graphic) GraphicConfig {
  return switch (graphic) {
    Graphic.Pit       => GraphicConfig{ .tx = 1, .ty = 1, .fliph = false },
    Graphic.PlaBullet => GraphicConfig{ .tx = 2, .ty = 2, .fliph = true },
    Graphic.PlaBullet2=> GraphicConfig{ .tx = 9, .ty = 2, .fliph = true },
    Graphic.PlaBullet3=> GraphicConfig{ .tx =10, .ty = 2, .fliph = true },
    Graphic.PlaSpark1 => GraphicConfig{ .tx = 1, .ty = 2, .fliph = true },
    Graphic.PlaSpark2 => GraphicConfig{ .tx = 0, .ty = 2, .fliph = true },
    Graphic.MonBullet => GraphicConfig{ .tx = 2, .ty = 4, .fliph = true },
    Graphic.MonSpark1 => GraphicConfig{ .tx = 1, .ty = 4, .fliph = true },
    Graphic.MonSpark2 => GraphicConfig{ .tx = 0, .ty = 4, .fliph = true },
    Graphic.Floor     => GraphicConfig{ .tx = 4, .ty = 1, .fliph = false },
    Graphic.Man1      => GraphicConfig{ .tx = 3, .ty = 2, .fliph = true },
    Graphic.Man2      => GraphicConfig{ .tx = 4, .ty = 2, .fliph = true },
    Graphic.ManDying1 => GraphicConfig{ .tx = 2, .ty = 1, .fliph = false },
    Graphic.ManDying2 => GraphicConfig{ .tx = 3, .ty = 1, .fliph = false },
    Graphic.ManDying3 => GraphicConfig{ .tx = 6, .ty = 1, .fliph = false },
    Graphic.ManDying4 => GraphicConfig{ .tx = 7, .ty = 1, .fliph = false },
    Graphic.ManDying5 => GraphicConfig{ .tx = 8, .ty = 1, .fliph = false },
    Graphic.ManDying6 => GraphicConfig{ .tx = 9, .ty = 1, .fliph = false },
    Graphic.Wall,
    Graphic.Wall2     => GraphicConfig{ .tx = 5, .ty = 1, .fliph = false },
    Graphic.Spider1   => GraphicConfig{ .tx = 3, .ty = 3, .fliph = true },
    Graphic.Spider2   => GraphicConfig{ .tx = 4, .ty = 3, .fliph = true },
    Graphic.Explode1  => GraphicConfig{ .tx = 5, .ty = 3, .fliph = false },
    Graphic.Explode2  => GraphicConfig{ .tx = 6, .ty = 3, .fliph = false },
    Graphic.Explode3  => GraphicConfig{ .tx = 7, .ty = 3, .fliph = false },
    Graphic.Explode4  => GraphicConfig{ .tx = 8, .ty = 3, .fliph = false },
    Graphic.Spawn1    => GraphicConfig{ .tx = 2, .ty = 3, .fliph = false },
    Graphic.Spawn2    => GraphicConfig{ .tx = 1, .ty = 3, .fliph = false },
    Graphic.Squid1    => GraphicConfig{ .tx = 3, .ty = 4, .fliph = true },
    Graphic.Squid2    => GraphicConfig{ .tx = 4, .ty = 4, .fliph = true },
    Graphic.PowerUp   => GraphicConfig{ .tx = 8, .ty = 2, .fliph = false },
    Graphic.SpeedUp   => GraphicConfig{ .tx = 7, .ty = 2, .fliph = false },
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
