const StackAllocator = @import("../zigutils/src/traits/StackAllocator.zig").StackAllocator;

const Draw = @import("draw.zig");
const Platform = @import("platform/index.zig");
const loadPcx = @import("load_pcx.zig").loadPcx;

const FONT_FILENAME = "../assets/font.pcx";
const FONT_CHAR_WIDTH = 8;
const FONT_CHAR_HEIGHT = 8;
const FONT_NUM_COLS = 16;
const FONT_NUM_ROWS = 8;

pub const Font = struct{
  tileset: Draw.Tileset,
};

pub fn loadFont(stack: *StackAllocator, font: *Font) !void {
  const mark = stack.get_mark();
  defer stack.free_to_mark(mark);

  const img = try loadPcx(stack, FONT_FILENAME, 0);

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
