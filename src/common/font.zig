const build_options = @import("build_options");
const HunkSide = @import("zig-hunk").HunkSide;

const pdraw = @import("pdraw");
const draw = @import("draw.zig");
const pcx_helper = @import("pcx_helper.zig");

const FONT_FILENAME = build_options.assets_path ++ "/font.pcx";
const FONT_CHAR_WIDTH = 8;
const FONT_CHAR_HEIGHT = 8;
const FONT_NUM_COLS = 16;
const FONT_NUM_ROWS = 8;

pub const Font = struct {
    tileset: draw.Tileset,
};

pub fn loadFont(hunk_side: *HunkSide, font: *Font) pcx_helper.LoadPcxError!void {
    const mark = hunk_side.getMark();
    defer hunk_side.freeToMark(mark);

    const img = try pcx_helper.loadPcx(hunk_side, FONT_FILENAME, 0);

    font.tileset = draw.Tileset {
        .texture = pdraw.uploadTexture(img.width, img.height, img.pixels),
        .xtiles = FONT_NUM_COLS,
        .ytiles = FONT_NUM_ROWS,
    };
}

pub fn fontDrawString(ds: *pdraw.DrawState, font: *const Font, x: i32, y: i32, string: []const u8) void {
    var ix = x;
    const w = FONT_CHAR_WIDTH;
    const h = FONT_CHAR_HEIGHT;
    for (string) |char| {
        const tile = draw.Tile {
            .tx = char % FONT_NUM_COLS,
            .ty = char / FONT_NUM_COLS,
        };
        pdraw.tile(ds, font.tileset, tile, ix, y, w, h, .Identity);
        ix += FONT_CHAR_WIDTH;
    }
}
