const DoubleStackAllocatorFlat = @import("../../zigutils/src/DoubleStackAllocatorFlat.zig").DoubleStackAllocatorFlat;

const Platform = @import("../platform/index.zig");
const loadPcx = @import("../load_pcx.zig").loadPcx;
const Draw = @import("../draw.zig");

const GRAPHICS_FILENAME = "../assets/mytiles.pcx";
const TRANSPARENT_COLOR_INDEX = 27;

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
  EvilWallTL,
  EvilWallTR,
  EvilWallBL,
  EvilWallBR,
  Spider1,
  Spider2,
  FastBug1,
  FastBug2,
  Juggernaut,
  Explode1,
  Explode2,
  Explode3,
  Explode4,
  Spawn1,
  Spawn2,
  Squid1,
  Squid2,
  Knight1,
  Knight2,
  Web1,
  Web2,
  PowerUp,
  SpeedUp,
  LifeUp,
  Coin,
};

pub fn getGraphicTile(graphic: Graphic) Draw.Tile {
  return switch (graphic) {
    Graphic.Pit        => Draw.Tile{ .tx = 1, .ty = 0 },
    Graphic.Floor      => Draw.Tile{ .tx = 2, .ty = 0 },
    Graphic.Wall       => Draw.Tile{ .tx = 3, .ty = 0 },
    Graphic.Wall2      => Draw.Tile{ .tx = 4, .ty = 0 },
    Graphic.EvilWallTL => Draw.Tile{ .tx = 0, .ty = 6 },
    Graphic.EvilWallTR => Draw.Tile{ .tx = 1, .ty = 6 },
    Graphic.EvilWallBL => Draw.Tile{ .tx = 0, .ty = 7 },
    Graphic.EvilWallBR => Draw.Tile{ .tx = 1, .ty = 7 },
    Graphic.PlaBullet  => Draw.Tile{ .tx = 2, .ty = 1 },
    Graphic.PlaBullet2 => Draw.Tile{ .tx = 3, .ty = 1 },
    Graphic.PlaBullet3 => Draw.Tile{ .tx = 4, .ty = 1 },
    Graphic.PlaSpark1  => Draw.Tile{ .tx = 1, .ty = 1 },
    Graphic.PlaSpark2  => Draw.Tile{ .tx = 0, .ty = 1 },
    Graphic.MonBullet  => Draw.Tile{ .tx = 2, .ty = 3 },
    Graphic.MonSpark1  => Draw.Tile{ .tx = 1, .ty = 3 },
    Graphic.MonSpark2  => Draw.Tile{ .tx = 0, .ty = 3 },
    Graphic.Man1       => Draw.Tile{ .tx = 6, .ty = 1 },
    Graphic.Man2       => Draw.Tile{ .tx = 7, .ty = 1 },
    Graphic.ManDying1  => Draw.Tile{ .tx = 0, .ty = 4 },
    Graphic.ManDying2  => Draw.Tile{ .tx = 1, .ty = 4 },
    Graphic.ManDying3  => Draw.Tile{ .tx = 2, .ty = 4 },
    Graphic.ManDying4  => Draw.Tile{ .tx = 3, .ty = 4 },
    Graphic.ManDying5  => Draw.Tile{ .tx = 4, .ty = 4 },
    Graphic.ManDying6  => Draw.Tile{ .tx = 5, .ty = 4 },
    Graphic.Spider1    => Draw.Tile{ .tx = 3, .ty = 2 },
    Graphic.Spider2    => Draw.Tile{ .tx = 4, .ty = 2 },
    Graphic.FastBug1   => Draw.Tile{ .tx = 5, .ty = 2 },
    Graphic.FastBug2   => Draw.Tile{ .tx = 6, .ty = 2 },
    Graphic.Juggernaut => Draw.Tile{ .tx = 7, .ty = 2 },
    Graphic.Explode1   => Draw.Tile{ .tx = 0, .ty = 5 },
    Graphic.Explode2   => Draw.Tile{ .tx = 1, .ty = 5 },
    Graphic.Explode3   => Draw.Tile{ .tx = 2, .ty = 5 },
    Graphic.Explode4   => Draw.Tile{ .tx = 3, .ty = 5 },
    Graphic.Spawn1     => Draw.Tile{ .tx = 2, .ty = 2 },
    Graphic.Spawn2     => Draw.Tile{ .tx = 1, .ty = 2 },
    Graphic.Squid1     => Draw.Tile{ .tx = 3, .ty = 3 },
    Graphic.Squid2     => Draw.Tile{ .tx = 4, .ty = 3 },
    Graphic.Knight1    => Draw.Tile{ .tx = 5, .ty = 3 },
    Graphic.Knight2    => Draw.Tile{ .tx = 6, .ty = 3 },
    Graphic.Web1       => Draw.Tile{ .tx = 6, .ty = 4 },
    Graphic.Web2       => Draw.Tile{ .tx = 7, .ty = 4 },
    Graphic.LifeUp     => Draw.Tile{ .tx = 4, .ty = 5 },
    Graphic.PowerUp    => Draw.Tile{ .tx = 6, .ty = 5 },
    Graphic.SpeedUp    => Draw.Tile{ .tx = 5, .ty = 5 },
    Graphic.Coin       => Draw.Tile{ .tx = 4, .ty = 6 },
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
      .ticks_per_frame = 6,
    },
    SimpleAnim.MonSparks => SimpleAnimConfig{
      .frames = ([2]Graphic{
        Graphic.MonSpark1,
        Graphic.MonSpark2,
      })[0..],
      .ticks_per_frame = 6,
    },
    SimpleAnim.Explosion => SimpleAnimConfig{
      .frames = ([4]Graphic{
        Graphic.Explode1,
        Graphic.Explode2,
        Graphic.Explode3,
        Graphic.Explode4,
      })[0..],
      .ticks_per_frame = 6,
    }
  };
}

pub fn loadTileset(dsaf: *DoubleStackAllocatorFlat, out_tileset: *Draw.Tileset) !void {
  const low_mark = dsaf.get_low_mark();
  defer dsaf.free_to_low_mark(low_mark);

  const img = try loadPcx(dsaf, GRAPHICS_FILENAME, TRANSPARENT_COLOR_INDEX);

  out_tileset.texture = Platform.uploadTexture(img);
  out_tileset.xtiles = 8;
  out_tileset.ytiles = 8;
}
