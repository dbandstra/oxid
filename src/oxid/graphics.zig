const build_options = @import("build_options");
const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const pdraw = @import("root").pdraw;
const pcx_helper = @import("../common/pcx_helper.zig");
const drawing = @import("../common/drawing.zig");
const constants = @import("constants.zig");

const graphics_filename = build_options.assets_path ++ "/mytiles.pcx";
const transparent_color_index = 27;

// named colors for the dawnbringer palette
pub const Color = enum {
    black,
    burgundy,
    navy,
    darkgray,
    brown,
    darkgreen,
    salmon,
    mediumgray,
    skyblue,
    orange,
    lightgray,
    lightgreen,
    peach,
    lightcyan,
    yellow,
    white,
};

pub fn getColor(palette: [48]u8, color: Color) drawing.Color {
    const index: usize = @enumToInt(color);
    return .{
        .r = palette[index * 3 + 0],
        .g = palette[index * 3 + 1],
        .b = palette[index * 3 + 2],
    };
}

pub const Graphic = enum {
    pit,
    pla_bullet,
    pla_bullet2,
    pla_bullet3,
    pla_spark1,
    pla_spark2,
    mon_bullet,
    mon_spark1,
    mon_spark2,
    floor,
    floor_shadow,
    man_icons,
    man1_walk1,
    man1_walk2,
    man2_walk1,
    man2_walk2,
    man1_choke,
    man2_choke,
    man_dying1,
    man_dying2,
    man_dying3,
    man_dying4,
    man_dying5,
    man_dying6,
    wall,
    wall2,
    evilwall_tl,
    evilwall_tr,
    evilwall_bl,
    evilwall_br,
    station_tl,
    station_tr,
    station_bl,
    station_br,
    station_sl,
    station_sr,
    spider1,
    spider2,
    fast_bug1,
    fast_bug2,
    juggernaut,
    explode1,
    explode2,
    explode3,
    explode4,
    spawn1,
    spawn2,
    squid1,
    squid2,
    knight1,
    knight2,
    web1,
    web2,
    power_up,
    speed_up,
    life_up,
    coin,
};

pub fn getGraphicTile(graphic: Graphic) drawing.Tile {
    return switch (graphic) {
        .pit => .{ .tx = 1, .ty = 0 },
        .floor => .{ .tx = 2, .ty = 0 },
        .floor_shadow => .{ .tx = 5, .ty = 0 },
        .wall => .{ .tx = 3, .ty = 0 },
        .wall2 => .{ .tx = 4, .ty = 0 },
        .evilwall_tl => .{ .tx = 0, .ty = 6 },
        .evilwall_tr => .{ .tx = 1, .ty = 6 },
        .evilwall_bl => .{ .tx = 0, .ty = 7 },
        .evilwall_br => .{ .tx = 1, .ty = 7 },
        .station_tl => .{ .tx = 6, .ty = 5 },
        .station_tr => .{ .tx = 7, .ty = 5 },
        .station_bl => .{ .tx = 6, .ty = 6 },
        .station_br => .{ .tx = 7, .ty = 6 },
        .station_sl => .{ .tx = 6, .ty = 7 },
        .station_sr => .{ .tx = 7, .ty = 7 },
        .pla_bullet => .{ .tx = 2, .ty = 1 },
        .pla_bullet2 => .{ .tx = 3, .ty = 1 },
        .pla_bullet3 => .{ .tx = 4, .ty = 1 },
        .pla_spark1 => .{ .tx = 1, .ty = 1 },
        .pla_spark2 => .{ .tx = 0, .ty = 1 },
        .mon_bullet => .{ .tx = 2, .ty = 3 },
        .mon_spark1 => .{ .tx = 1, .ty = 3 },
        .mon_spark2 => .{ .tx = 0, .ty = 3 },
        .man_icons => .{ .tx = 5, .ty = 1 },
        .man1_walk1 => .{ .tx = 6, .ty = 1 },
        .man1_walk2 => .{ .tx = 7, .ty = 1 },
        .man2_walk1 => .{ .tx = 6, .ty = 0 },
        .man2_walk2 => .{ .tx = 7, .ty = 0 },
        .man1_choke => .{ .tx = 2, .ty = 6 },
        .man2_choke => .{ .tx = 3, .ty = 6 },
        .man_dying1 => .{ .tx = 0, .ty = 4 },
        .man_dying2 => .{ .tx = 1, .ty = 4 },
        .man_dying3 => .{ .tx = 2, .ty = 4 },
        .man_dying4 => .{ .tx = 3, .ty = 4 },
        .man_dying5 => .{ .tx = 4, .ty = 4 },
        .man_dying6 => .{ .tx = 5, .ty = 4 },
        .spider1 => .{ .tx = 3, .ty = 2 },
        .spider2 => .{ .tx = 4, .ty = 2 },
        .fast_bug1 => .{ .tx = 5, .ty = 2 },
        .fast_bug2 => .{ .tx = 6, .ty = 2 },
        .juggernaut => .{ .tx = 7, .ty = 2 },
        .explode1 => .{ .tx = 0, .ty = 5 },
        .explode2 => .{ .tx = 1, .ty = 5 },
        .explode3 => .{ .tx = 2, .ty = 5 },
        .explode4 => .{ .tx = 3, .ty = 5 },
        .spawn1 => .{ .tx = 2, .ty = 2 },
        .spawn2 => .{ .tx = 1, .ty = 2 },
        .squid1 => .{ .tx = 3, .ty = 3 },
        .squid2 => .{ .tx = 4, .ty = 3 },
        .knight1 => .{ .tx = 5, .ty = 3 },
        .knight2 => .{ .tx = 6, .ty = 3 },
        .web1 => .{ .tx = 6, .ty = 4 },
        .web2 => .{ .tx = 7, .ty = 4 },
        .life_up => .{ .tx = 7, .ty = 3 },
        .power_up => .{ .tx = 5, .ty = 5 },
        .speed_up => .{ .tx = 4, .ty = 5 },
        .coin => .{ .tx = 0, .ty = 2 },
    };
}

pub const SimpleAnim = enum {
    pla_sparks,
    mon_sparks,
    explosion,
};

pub const SimpleAnimConfig = struct {
    frames: []const Graphic,
    ticks_per_frame: u32,
};

pub fn getSimpleAnim(simpleAnim: SimpleAnim) SimpleAnimConfig {
    return switch (simpleAnim) {
        .pla_sparks => .{
            .frames = &[_]Graphic{ .pla_spark1, .pla_spark2 },
            .ticks_per_frame = constants.duration60(6),
        },
        .mon_sparks => .{
            .frames = &[_]Graphic{ .mon_spark1, .mon_spark2 },
            .ticks_per_frame = constants.duration60(6),
        },
        .explosion => .{
            .frames = &[_]Graphic{ .explode1, .explode2, .explode3, .explode4 },
            .ticks_per_frame = constants.duration60(6),
        },
    };
}

pub fn loadTileset(
    ds: *pdraw.State,
    hunk_side: *HunkSide,
    out_tileset: *drawing.Tileset,
    out_palette: *[48]u8,
) !void {
    const mark = hunk_side.getMark();
    defer hunk_side.freeToMark(mark);

    const img = try pcx_helper.loadPcx(
        hunk_side,
        graphics_filename,
        transparent_color_index,
    );
    const w = try std.math.cast(u31, img.width);
    const h = try std.math.cast(u31, img.height);

    out_tileset.* = .{
        .texture = try pdraw.createTexture(ds, w, h, img.pixels),
        .num_cols = w / 16,
        .num_rows = h / 16,
        .tile_w = 16,
        .tile_h = 16,
    };

    std.mem.copy(u8, out_palette, &img.palette);
}

pub fn unloadTileset(tileset: *drawing.Tileset) void {
    pdraw.destroyTexture(tileset.texture);
}
