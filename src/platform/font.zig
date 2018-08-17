const DoubleStackAllocatorFlat = @import("../../zigutils/src/DoubleStackAllocatorFlat.zig").DoubleStackAllocatorFlat;

const Math = @import("../math.zig");
const Draw = @import("../draw.zig");
const Platform = @import("platform.zig");
const PlatformDraw = @import("draw.zig");
const uploadPcx = @import("upload_pcx.zig").uploadPcx;

const FONT_FILENAME = "../../assets/font.pcx";
const FONT_CHAR_WIDTH = 8;
const FONT_CHAR_HEIGHT = 8;
const FONT_NUM_COLS = 16;
const FONT_NUM_ROWS = 8;

pub const Font = struct{
  tileset: Draw.Tileset,
};

pub fn loadFont(dsaf: *DoubleStackAllocatorFlat, font: *Font) !void {
  font.tileset = Draw.Tileset{
    .texture = try uploadPcx(dsaf, FONT_FILENAME, null),
    .xtiles = FONT_NUM_COLS,
    .ytiles = FONT_NUM_ROWS,
  };
}

pub fn fontDrawString(ps: *Platform.State, pos: Math.Vec2, string: []const u8) void {
  const w = FONT_CHAR_WIDTH;
  const h = FONT_CHAR_HEIGHT;
  var x = pos.x;
  var y = pos.y;
  for (string) |char| {
    const fx = @intToFloat(f32, x);
    const fy = @intToFloat(f32, y);
    const tile = Draw.Tile{
      .tx = char % FONT_NUM_COLS,
      .ty = char / FONT_NUM_COLS,
    };
    PlatformDraw.tile(ps, &ps.font.tileset, tile, fx, fy, w, h, Draw.Transform.Identity);
    x += FONT_CHAR_WIDTH;
  }
}
