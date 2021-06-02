const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const pdraw = @import("root").pdraw;
const drawing = @import("drawing.zig");
const pcx_helper = @import("pcx_helper.zig");

pub const FontDef = struct {
    filename: []const u8,
    first_char: u8,
    char_width: u31,
    char_height: u31,
    spacing: i32,
};

pub const Font = struct {
    tileset: drawing.Tileset,
    first_char: u8,
    spacing: i32,
};

pub fn load(ds: *pdraw.State, hunk_side: *HunkSide, font: *Font, comptime def: FontDef) !void {
    const mark = hunk_side.getMark();
    defer hunk_side.freeToMark(mark);

    const img = try pcx_helper.loadPcx(hunk_side, def.filename, 0);
    const w = try std.math.cast(u31, img.width);
    const h = try std.math.cast(u31, img.height);
    const texture = try pdraw.createTexture(ds, w, h, img.pixels);

    font.* = .{
        .tileset = .{
            .texture = texture,
            .num_cols = w / def.char_width,
            .num_rows = h / def.char_height,
            .tile_w = def.char_width,
            .tile_h = def.char_height,
        },
        .first_char = def.first_char,
        .spacing = def.spacing,
    };
}

pub fn unload(font: *Font) void {
    pdraw.destroyTexture(font.tileset.texture);
}

pub fn stringWidth(font: *const Font, string: []const u8) u31 {
    if (string.len == 0)
        return 0;
    const w: u31 = font.tileset.tile_w;
    if (-font.spacing >= w)
        return 0;
    const w1 = @intCast(u31, @as(i32, w) + font.spacing);
    return w + w1 * @intCast(u31, string.len - 1);
}

pub fn drawString(ds: *pdraw.State, font: *const Font, x: i32, y: i32, string: []const u8) void {
    var ix = x;
    for (string) |char| {
        if (char < font.first_char) continue;
        const index = char - font.first_char;
        const tile: drawing.Tile = .{
            .tx = index % font.tileset.num_cols,
            .ty = index / font.tileset.num_cols,
        };
        pdraw.tile(ds, font.tileset, tile, ix, y, .identity);
        ix += @as(i32, font.tileset.tile_w) + font.spacing;
    }
}
