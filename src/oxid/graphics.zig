const build_options = @import("build_options");
const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;

const platform = @import("../platform.zig");
const pcx_helper = @import("../common/pcx_helper.zig");
const draw = @import("../common/draw.zig");

const GRAPHICS_FILENAME = build_options.assets_path ++ "/mytiles.pcx";
const TRANSPARENT_COLOR_INDEX = 27;

pub const Graphic = enum {
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

pub fn getGraphicTile(graphic: Graphic) draw.Tile {
    return switch (graphic) {
        Graphic.Pit        => draw.Tile { .tx = 1, .ty = 0 },
        Graphic.Floor      => draw.Tile { .tx = 2, .ty = 0 },
        Graphic.Wall       => draw.Tile { .tx = 3, .ty = 0 },
        Graphic.Wall2      => draw.Tile { .tx = 4, .ty = 0 },
        Graphic.EvilWallTL => draw.Tile { .tx = 0, .ty = 6 },
        Graphic.EvilWallTR => draw.Tile { .tx = 1, .ty = 6 },
        Graphic.EvilWallBL => draw.Tile { .tx = 0, .ty = 7 },
        Graphic.EvilWallBR => draw.Tile { .tx = 1, .ty = 7 },
        Graphic.PlaBullet  => draw.Tile { .tx = 2, .ty = 1 },
        Graphic.PlaBullet2 => draw.Tile { .tx = 3, .ty = 1 },
        Graphic.PlaBullet3 => draw.Tile { .tx = 4, .ty = 1 },
        Graphic.PlaSpark1  => draw.Tile { .tx = 1, .ty = 1 },
        Graphic.PlaSpark2  => draw.Tile { .tx = 0, .ty = 1 },
        Graphic.MonBullet  => draw.Tile { .tx = 2, .ty = 3 },
        Graphic.MonSpark1  => draw.Tile { .tx = 1, .ty = 3 },
        Graphic.MonSpark2  => draw.Tile { .tx = 0, .ty = 3 },
        Graphic.Man1       => draw.Tile { .tx = 6, .ty = 1 },
        Graphic.Man2       => draw.Tile { .tx = 7, .ty = 1 },
        Graphic.ManDying1  => draw.Tile { .tx = 0, .ty = 4 },
        Graphic.ManDying2  => draw.Tile { .tx = 1, .ty = 4 },
        Graphic.ManDying3  => draw.Tile { .tx = 2, .ty = 4 },
        Graphic.ManDying4  => draw.Tile { .tx = 3, .ty = 4 },
        Graphic.ManDying5  => draw.Tile { .tx = 4, .ty = 4 },
        Graphic.ManDying6  => draw.Tile { .tx = 5, .ty = 4 },
        Graphic.Spider1    => draw.Tile { .tx = 3, .ty = 2 },
        Graphic.Spider2    => draw.Tile { .tx = 4, .ty = 2 },
        Graphic.FastBug1   => draw.Tile { .tx = 5, .ty = 2 },
        Graphic.FastBug2   => draw.Tile { .tx = 6, .ty = 2 },
        Graphic.Juggernaut => draw.Tile { .tx = 7, .ty = 2 },
        Graphic.Explode1   => draw.Tile { .tx = 0, .ty = 5 },
        Graphic.Explode2   => draw.Tile { .tx = 1, .ty = 5 },
        Graphic.Explode3   => draw.Tile { .tx = 2, .ty = 5 },
        Graphic.Explode4   => draw.Tile { .tx = 3, .ty = 5 },
        Graphic.Spawn1     => draw.Tile { .tx = 2, .ty = 2 },
        Graphic.Spawn2     => draw.Tile { .tx = 1, .ty = 2 },
        Graphic.Squid1     => draw.Tile { .tx = 3, .ty = 3 },
        Graphic.Squid2     => draw.Tile { .tx = 4, .ty = 3 },
        Graphic.Knight1    => draw.Tile { .tx = 5, .ty = 3 },
        Graphic.Knight2    => draw.Tile { .tx = 6, .ty = 3 },
        Graphic.Web1       => draw.Tile { .tx = 6, .ty = 4 },
        Graphic.Web2       => draw.Tile { .tx = 7, .ty = 4 },
        Graphic.LifeUp     => draw.Tile { .tx = 4, .ty = 5 },
        Graphic.PowerUp    => draw.Tile { .tx = 6, .ty = 5 },
        Graphic.SpeedUp    => draw.Tile { .tx = 5, .ty = 5 },
        Graphic.Coin       => draw.Tile { .tx = 4, .ty = 6 },
    };
}

pub const SimpleAnim = enum {
    PlaSparks,
    MonSparks,
    Explosion,
};

pub const SimpleAnimConfig = struct {
    frames: []const Graphic,
    ticks_per_frame: u32,
};

pub fn getSimpleAnim(simpleAnim: SimpleAnim) SimpleAnimConfig {
    return switch (simpleAnim) {
        SimpleAnim.PlaSparks => SimpleAnimConfig {
            .frames = ([2]Graphic{
                Graphic.PlaSpark1,
                Graphic.PlaSpark2,
            })[0..],
            .ticks_per_frame = 6,
        },
        SimpleAnim.MonSparks => SimpleAnimConfig {
            .frames = ([2]Graphic{
                Graphic.MonSpark1,
                Graphic.MonSpark2,
            })[0..],
            .ticks_per_frame = 6,
        },
        SimpleAnim.Explosion => SimpleAnimConfig {
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

pub fn loadTileset(hunk_side: *HunkSide, out_tileset: *draw.Tileset, out_palette: []u8) pcx_helper.LoadPcxError!void {
    std.debug.assert(out_palette.len == 48);

    const mark = hunk_side.getMark();
    defer hunk_side.freeToMark(mark);

    const img = try pcx_helper.loadPcx(hunk_side, GRAPHICS_FILENAME, TRANSPARENT_COLOR_INDEX);

    out_tileset.texture = platform.uploadTexture(img.width, img.height, img.pixels);
    out_tileset.xtiles = 8;
    out_tileset.ytiles = 8;

    std.mem.copy(u8, out_palette, img.palette[0..]);
}
