const build_options = @import("build_options");
const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;

const pdraw = @import("pdraw");
const pcx_helper = @import("../common/pcx_helper.zig");
const draw = @import("../common/draw.zig");
const constants = @import("constants.zig");

const graphics_filename = build_options.assets_path ++ "/mytiles.pcx";
const transparent_color_index = 27;

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
    ManIcons,
    Man1Walk1,
    Man1Walk2,
    Man2Walk1,
    Man2Walk2,
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
        .Pit        => .{.tx = 1, .ty = 0},
        .Floor      => .{.tx = 2, .ty = 0},
        .Wall       => .{.tx = 3, .ty = 0},
        .Wall2      => .{.tx = 4, .ty = 0},
        .EvilWallTL => .{.tx = 0, .ty = 6},
        .EvilWallTR => .{.tx = 1, .ty = 6},
        .EvilWallBL => .{.tx = 0, .ty = 7},
        .EvilWallBR => .{.tx = 1, .ty = 7},
        .PlaBullet  => .{.tx = 2, .ty = 1},
        .PlaBullet2 => .{.tx = 3, .ty = 1},
        .PlaBullet3 => .{.tx = 4, .ty = 1},
        .PlaSpark1  => .{.tx = 1, .ty = 1},
        .PlaSpark2  => .{.tx = 0, .ty = 1},
        .MonBullet  => .{.tx = 2, .ty = 3},
        .MonSpark1  => .{.tx = 1, .ty = 3},
        .MonSpark2  => .{.tx = 0, .ty = 3},
        .ManIcons   => .{.tx = 5, .ty = 0},
        .Man1Walk1  => .{.tx = 6, .ty = 1},
        .Man1Walk2  => .{.tx = 7, .ty = 1},
        .Man2Walk1  => .{.tx = 6, .ty = 0},
        .Man2Walk2  => .{.tx = 7, .ty = 0},
        .ManDying1  => .{.tx = 0, .ty = 4},
        .ManDying2  => .{.tx = 1, .ty = 4},
        .ManDying3  => .{.tx = 2, .ty = 4},
        .ManDying4  => .{.tx = 3, .ty = 4},
        .ManDying5  => .{.tx = 4, .ty = 4},
        .ManDying6  => .{.tx = 5, .ty = 4},
        .Spider1    => .{.tx = 3, .ty = 2},
        .Spider2    => .{.tx = 4, .ty = 2},
        .FastBug1   => .{.tx = 5, .ty = 2},
        .FastBug2   => .{.tx = 6, .ty = 2},
        .Juggernaut => .{.tx = 7, .ty = 2},
        .Explode1   => .{.tx = 0, .ty = 5},
        .Explode2   => .{.tx = 1, .ty = 5},
        .Explode3   => .{.tx = 2, .ty = 5},
        .Explode4   => .{.tx = 3, .ty = 5},
        .Spawn1     => .{.tx = 2, .ty = 2},
        .Spawn2     => .{.tx = 1, .ty = 2},
        .Squid1     => .{.tx = 3, .ty = 3},
        .Squid2     => .{.tx = 4, .ty = 3},
        .Knight1    => .{.tx = 5, .ty = 3},
        .Knight2    => .{.tx = 6, .ty = 3},
        .Web1       => .{.tx = 6, .ty = 4},
        .Web2       => .{.tx = 7, .ty = 4},
        .LifeUp     => .{.tx = 4, .ty = 5},
        .PowerUp    => .{.tx = 6, .ty = 5},
        .SpeedUp    => .{.tx = 5, .ty = 5},
        .Coin       => .{.tx = 4, .ty = 6},
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
        .PlaSparks => .{
            .frames = &[_]Graphic { .PlaSpark1, .PlaSpark2 },
            .ticks_per_frame = constants.duration60(6),
        },
        .MonSparks => .{
            .frames = &[_]Graphic { .MonSpark1, .MonSpark2 },
            .ticks_per_frame = constants.duration60(6),
        },
        .Explosion => .{
            .frames = &[_]Graphic { .Explode1, .Explode2, .Explode3, .Explode4 },
            .ticks_per_frame = constants.duration60(6),
        }
    };
}

pub fn loadTileset(hunk_side: *HunkSide, out_tileset: *draw.Tileset, out_palette: []u8) pcx_helper.LoadPcxError!void {
    std.debug.assert(out_palette.len == 48);

    const mark = hunk_side.getMark();
    defer hunk_side.freeToMark(mark);

    const img = try pcx_helper.loadPcx(hunk_side, graphics_filename, transparent_color_index);

    out_tileset.texture = pdraw.uploadTexture(img.width, img.height, img.pixels);
    out_tileset.xtiles = 8;
    out_tileset.ytiles = 8;

    std.mem.copy(u8, out_palette, img.palette[0..]);
}
