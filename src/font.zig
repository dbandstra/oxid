const c = @import("c.zig");
use @import("math3d.zig");

const DoubleStackAllocatorFlat = @import("../zigutils/src/DoubleStackAllocatorFlat.zig").DoubleStackAllocatorFlat;
const MemoryInStream = @import("../zigutils/src/MemoryInStream.zig").MemoryInStream;
const image = @import("../zigutils/src/image/image.zig");
const LoadPcx = @import("../zigutils/src/image/pcx.zig").LoadPcx;
const pcxBestStoreFormat = @import("../zigutils/src/image/pcx.zig").pcxBestStoreFormat;

const Math = @import("math.zig");

const GameState = @import("main.zig").GameState;
const Texture = @import("main.zig").Texture;
const uploadTexture = @import("main.zig").uploadTexture;

const FONT_FILENAME = "../assets/font.pcx";
const FONT_CHAR_WIDTH = 8;
const FONT_CHAR_HEIGHT = 8;
const FONT_NUM_COLS = 16;
const FONT_NUM_ROWS = 8;

pub const Font = struct{
  texture: Texture,
};

// return an Image allocated in the low_allocator
fn load_fontset(dsaf: *DoubleStackAllocatorFlat) !*image.Image {
  const high_mark = dsaf.get_high_mark();
  defer dsaf.free_to_high_mark(high_mark);

  const filename = FONT_FILENAME;

  var source = MemoryInStream.init(@embedFile(filename));

  // load pcx
  const pcxInfo = try LoadPcx(MemoryInStream.ReadError).preload(&source.stream, &source.seekable);
  const img = try image.createImage(&dsaf.high_allocator, image.Info{
    .width = pcxInfo.width,
    .height = pcxInfo.height,
    .format = pcxBestStoreFormat(pcxInfo),
  });
  try LoadPcx(MemoryInStream.ReadError).load(&source.stream, &source.seekable, pcxInfo, img);

  // load palette
  const palette = try image.createPalette(&dsaf.high_allocator);
  try LoadPcx(MemoryInStream.ReadError).loadPalette(&source.stream, &source.seekable, pcxInfo, palette);

  // convert to true color image
  const img2 = try image.createImage(&dsaf.low_allocator, image.Info{
    .width = img.info.width,
    .height = img.info.height,
    .format = image.Format.RGBA,
  });
  image.convertToTrueColor(img2, img, palette, null);

  return img2;
}

pub fn load_font(dsaf: *DoubleStackAllocatorFlat, font: *Font) !void {
  const low_mark = dsaf.get_low_mark();
  defer dsaf.free_to_low_mark(low_mark);

  const fontset = try load_fontset(dsaf);

  font.texture = uploadTexture(fontset);
}

pub fn font_drawchar(g: *GameState, pos: Math.Vec2, char: u8) void {
  const texid = g.font.texture.handle;
  const x = @intToFloat(f32, pos.x);
  const y = @intToFloat(f32, pos.y);
  const w = FONT_CHAR_WIDTH;
  const h = FONT_CHAR_HEIGHT;

  const model = mat4x4_identity.translate(x, y, 0.0).scale(w, h, 0.0);
  const mvp = g.projection.mult(model);

  const tx = char % FONT_NUM_COLS;
  const ty = char / FONT_NUM_COLS;
  if (ty >= FONT_NUM_ROWS) {
    return;
  }
  const pos_x = @intToFloat(f32, tx) / f32(FONT_NUM_COLS);
  const pos_y = @intToFloat(f32, ty) / f32(FONT_NUM_ROWS);
  const dims_x = 1 / f32(FONT_NUM_COLS);
  const dims_y = 1 / f32(FONT_NUM_ROWS);

  g.shaders.texture.bind();
  g.shaders.texture.set_uniform_int(g.shaders.texture_uniform_tex, 0);
  g.shaders.texture.set_uniform_mat4x4(g.shaders.texture_uniform_mvp, mvp);
  g.shaders.texture.set_uniform_vec2(g.shaders.texture_uniform_region_pos, pos_x, pos_y);
  g.shaders.texture.set_uniform_vec2(g.shaders.texture_uniform_region_dims, dims_x, dims_y);

  if (g.shaders.texture_attrib_position >= 0) { // ?
    c.glBindBuffer(c.GL_ARRAY_BUFFER, g.static_geometry.rect_2d_vertex_buffer);
    c.glEnableVertexAttribArray(@intCast(c.GLuint, g.shaders.texture_attrib_position));
    c.glVertexAttribPointer(@intCast(c.GLuint, g.shaders.texture_attrib_position), 3, c.GL_FLOAT, c.GL_FALSE, 0, null);
  }

  if (g.shaders.texture_attrib_tex_coord >= 0) { // ?
    c.glBindBuffer(c.GL_ARRAY_BUFFER, g.static_geometry.rect_2d_tex_coord_buffer_normal);
    c.glEnableVertexAttribArray(@intCast(c.GLuint, g.shaders.texture_attrib_tex_coord));
    c.glVertexAttribPointer(@intCast(c.GLuint, g.shaders.texture_attrib_tex_coord), 2, c.GL_FLOAT, c.GL_FALSE, 0, null);
  }

  c.glActiveTexture(c.GL_TEXTURE0);
  c.glBindTexture(c.GL_TEXTURE_2D, texid);

  c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
}

pub fn font_drawstring(g: *GameState, pos: Math.Vec2, string: []const u8) void {
  var x = pos.x;
  var y = pos.y;
  for (string) |char| {
    font_drawchar(g, Math.Vec2.init(x, y), char);
    x += FONT_CHAR_WIDTH;
  }
}
