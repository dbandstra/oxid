const build_options = @import("build_options");
const HunkSide = @import("zig-hunk").HunkSide;

const pdraw = @import("pdraw");
const draw = @import("draw.zig");
const pcx_helper = @import("pcx_helper.zig");

const font_filename = build_options.assets_path ++ "/font.pcx";
pub const font_char_width = 8;
pub const font_char_height = 8;
const font_num_cols = 16;
const font_num_rows = 8;

pub const Font = struct {
    tileset: draw.Tileset,
};

pub fn loadFont(hunk_side: *HunkSide, font: *Font) pcx_helper.LoadPcxError!void {
    const mark = hunk_side.getMark();
    defer hunk_side.freeToMark(mark);

    const img = try pcx_helper.loadPcx(hunk_side, font_filename, 0);

    font.tileset = .{
        .texture = pdraw.uploadTexture(img.width, img.height, img.pixels),
        .xtiles = font_num_cols,
        .ytiles = font_num_rows,
    };
}

pub fn fontDrawString(
    ds: *pdraw.DrawState,
    font: *const Font,
    x: i32,
    y: i32,
    string: []const u8,
) void {
    var ix = x;
    const w = font_char_width;
    const h = font_char_height;
    for (string) |char| {
        const tile: draw.Tile = .{
            .tx = char % font_num_cols,
            .ty = char / font_num_cols,
        };
        pdraw.tile(ds, font.tileset, tile, ix, y, w, h, .identity);
        ix += font_char_width;
    }
}
