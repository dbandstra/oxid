const c = @import("platform/c.zig");
use @import("math3d.zig");

const DoubleStackAllocatorFlat = @import("../zigutils/src/DoubleStackAllocatorFlat.zig").DoubleStackAllocatorFlat;
const MemoryInStream = @import("../zigutils/src/MemoryInStream.zig").MemoryInStream;
const image = @import("../zigutils/src/image/image.zig");
const LoadPcx = @import("../zigutils/src/image/pcx.zig").LoadPcx;
const pcxBestStoreFormat = @import("../zigutils/src/image/pcx.zig").pcxBestStoreFormat;

const Math = @import("math.zig");
const Platform = @import("platform/platform.zig");

const FONT_FILENAME = "../assets/font.pcx";
const FONT_CHAR_WIDTH = 8;
const FONT_CHAR_HEIGHT = 8;
const FONT_NUM_COLS = 16;
const FONT_NUM_ROWS = 8;

pub const Font = struct{
  texture: Platform.Texture,
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

  font.texture = Platform.uploadTexture(fontset);
}

// TODO - move to platform
pub fn font_drawchar(ps: *Platform.State, pos: Math.Vec2, char: u8) void {
  const texid = ps.font.texture.handle;
  const x = @intToFloat(f32, pos.x);
  const y = @intToFloat(f32, pos.y);
  const w = FONT_CHAR_WIDTH;
  const h = FONT_CHAR_HEIGHT;

  const model = mat4x4_identity.translate(x, y, 0.0).scale(w, h, 0.0);
  const mvp = ps.projection.mult(model);

  const tx = char % FONT_NUM_COLS;
  const ty = char / FONT_NUM_COLS;
  if (ty >= FONT_NUM_ROWS) {
    return;
  }
  const pos_x = @intToFloat(f32, tx) / f32(FONT_NUM_COLS);
  const pos_y = @intToFloat(f32, ty) / f32(FONT_NUM_ROWS);
  const dims_x = 1 / f32(FONT_NUM_COLS);
  const dims_y = 1 / f32(FONT_NUM_ROWS);

  ps.shaders.texture.bind();
  ps.shaders.texture.set_uniform_int(ps.shaders.texture_uniform_tex, 0);
  ps.shaders.texture.set_uniform_mat4x4(ps.shaders.texture_uniform_mvp, mvp);
  ps.shaders.texture.set_uniform_vec2(ps.shaders.texture_uniform_region_pos, pos_x, pos_y);
  ps.shaders.texture.set_uniform_vec2(ps.shaders.texture_uniform_region_dims, dims_x, dims_y);

  if (ps.shaders.texture_attrib_position >= 0) { // ?
    c.glBindBuffer(c.GL_ARRAY_BUFFER, ps.static_geometry.rect_2d_vertex_buffer);
    c.glEnableVertexAttribArray(@intCast(c.GLuint, ps.shaders.texture_attrib_position));
    c.glVertexAttribPointer(@intCast(c.GLuint, ps.shaders.texture_attrib_position), 3, c.GL_FLOAT, c.GL_FALSE, 0, null);
  }

  if (ps.shaders.texture_attrib_tex_coord >= 0) { // ?
    c.glBindBuffer(c.GL_ARRAY_BUFFER, ps.static_geometry.rect_2d_tex_coord_buffer_normal);
    c.glEnableVertexAttribArray(@intCast(c.GLuint, ps.shaders.texture_attrib_tex_coord));
    c.glVertexAttribPointer(@intCast(c.GLuint, ps.shaders.texture_attrib_tex_coord), 2, c.GL_FLOAT, c.GL_FALSE, 0, null);
  }

  c.glActiveTexture(c.GL_TEXTURE0);
  c.glBindTexture(c.GL_TEXTURE_2D, texid);

  c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);
}

pub fn font_drawstring(ps: *Platform.State, pos: Math.Vec2, string: []const u8) void {
  var x = pos.x;
  var y = pos.y;
  for (string) |char| {
    font_drawchar(ps, Math.Vec2.init(x, y), char);
    x += FONT_CHAR_WIDTH;
  }
}
