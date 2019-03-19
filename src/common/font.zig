const build_options = @import("build_options");
const HunkSide = @import("zig-hunk").HunkSide;

const Draw = @import("draw.zig");
const Platform = @import("platform/index.zig");
const LoadPcxError = @import("load_pcx.zig").LoadPcxError;
const loadPcx = @import("load_pcx.zig").loadPcx;

const FONT_FILENAME = build_options.assets_path ++ "/font.pcx";
const FONT_CHAR_WIDTH = 8;
const FONT_CHAR_HEIGHT = 8;
const FONT_NUM_COLS = 16;
const FONT_NUM_ROWS = 8;

pub const Font = struct{
  tileset: Draw.Tileset,
};

pub fn loadFont(hunk_side: *HunkSide, font: *Font) LoadPcxError!void {
  const mark = hunk_side.getMark();
  defer hunk_side.freeToMark(mark);

  const img = try loadPcx(hunk_side, FONT_FILENAME, 0);

  font.tileset = Draw.Tileset{
    .texture = Platform.uploadTexture(img),
    .xtiles = FONT_NUM_COLS,
    .ytiles = FONT_NUM_ROWS,
  };
}

pub fn fontDrawString(ps: *Platform.State, font: *const Font, x: i32, y: i32, string: []const u8) void {
  var ix = x;
  const w = FONT_CHAR_WIDTH;
  const h = FONT_CHAR_HEIGHT;
  for (string) |char| {
    const fx = @intToFloat(f32, ix);
    const fy = @intToFloat(f32, y);
    const tile = Draw.Tile{
      .tx = char % FONT_NUM_COLS,
      .ty = char / FONT_NUM_COLS,
    };
    Platform.drawTile(ps, &font.tileset, tile, fx, fy, w, h, Draw.Transform.Identity);
    ix += FONT_CHAR_WIDTH;
  }
}
