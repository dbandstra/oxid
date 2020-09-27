const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const pdraw = @import("pdraw");
const draw = @import("draw.zig");
const pcx_helper = @import("pcx_helper.zig");

pub const FontDef = struct {
    filename: []const u8,
    first_char: u8,
    char_width: u31,
    char_height: u31,
    num_cols: u31,
    num_rows: u31,
    spacing: i32,
};

pub const Font = struct {
    tileset: draw.Tileset,
    first_char: u8,
    char_width: u31,
    char_height: u31,
    spacing: i32,
};

pub fn load(hunk_side: *HunkSide, font: *Font, comptime def: FontDef) !void {
    const mark = hunk_side.getMark();
    defer hunk_side.freeToMark(mark);

    const img = try pcx_helper.loadPcx(hunk_side, def.filename, 0);

    font.* = .{
        .tileset = .{
            .texture = pdraw.uploadTexture(img.width, img.height, img.pixels),
            .xtiles = def.num_cols,
            .ytiles = def.num_rows,
        },
        .first_char = def.first_char,
        .char_width = def.char_width,
        .char_height = def.char_height,
        .spacing = def.spacing,
    };
}

pub fn stringWidth(font: *const Font, string: []const u8) u31 {
    var x: i32 = 0;
    for (string) |char, i| {
        if (i > 0) {
            x += font.spacing;
        }
        x += @as(i32, font.char_width);
    }
    return @intCast(u31, std.math.max(0, x));
}

pub fn drawString(ds: *pdraw.DrawState, font: *const Font, x: i32, y: i32, string: []const u8) void {
    var ix = x;
    for (string) |char| {
        if (char < font.first_char) continue;
        const index = char - font.first_char;
        const tile: draw.Tile = .{
            .tx = index % font.tileset.xtiles,
            .ty = index / font.tileset.xtiles,
        };
        pdraw.tile(ds, font.tileset, tile, ix, y, font.char_width, font.char_height, .identity);
        ix += @as(i32, font.char_width) + font.spacing;
    }
}
