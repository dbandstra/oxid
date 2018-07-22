const DoubleStackAllocatorFlat = @import("../zigutils/src/DoubleStackAllocatorFlat.zig").DoubleStackAllocatorFlat;
const MemoryInStream = @import("../zigutils/src/MemoryInStream.zig").MemoryInStream;
const image = @import("../zigutils/src/image/image.zig");
const LoadPcx = @import("../zigutils/src/image/pcx.zig").LoadPcx;
const pcxBestStoreFormat = @import("../zigutils/src/image/pcx.zig").pcxBestStoreFormat;

const Texture = @import("main.zig").Texture;
const uploadTexture = @import("main.zig").uploadTexture;

const GRAPHICS_FILENAME = @import("game_graphics_config.zig").GRAPHICS_FILENAME;
const TRANSPARENT_COLOR_INDEX = @import("game_graphics_config.zig").TRANSPARENT_COLOR_INDEX;
const Graphic = @import("game_graphics_config.zig").Graphic;
const getGraphicConfig = @import("game_graphics_config.zig").getGraphicConfig;

pub const Graphics = struct{
  background_colour: image.Pixel,
  textures: [@memberCount(Graphic)]Texture,

  pub fn texture(self: *Graphics, graphic: Graphic) *Texture {
    return &self.textures[@enumToInt(graphic)];
  }
};

// return an Image allocated in the low_allocator
fn loadTileset(dsaf: *DoubleStackAllocatorFlat, out_background_colour: *image.Pixel) !*image.Image {
  const high_mark = dsaf.get_high_mark();
  defer dsaf.free_to_high_mark(high_mark);

  var source = MemoryInStream.init(@embedFile(GRAPHICS_FILENAME));

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
  image.convertToTrueColor(img2, img, palette, TRANSPARENT_COLOR_INDEX);

  out_background_colour.* = image.getColor(palette.format, palette.data, TRANSPARENT_COLOR_INDEX);

  return img2;
}

pub fn loadGraphics(dsaf: *DoubleStackAllocatorFlat, graphics: *Graphics) !void {
  const low_mark = dsaf.get_low_mark();
  defer dsaf.free_to_low_mark(low_mark);

  const tileset = try loadTileset(dsaf, &graphics.background_colour);

  const tile = try image.createImage(&dsaf.low_allocator, image.Info{
    .width = 16,
    .height = 16,
    .format = image.Format.RGBA,
  });

  for (@typeInfo(Graphic).Enum.fields) |field| {
    const graphic = @intToEnum(Graphic, @intCast(@typeInfo(Graphic).Enum.tag_type, field.value));
    const config = getGraphicConfig(graphic);
    extractTile(tile, tileset, config.tx, config.ty);
    if (config.fliph) {
      image.flipHorizontal(tile);
    }
    graphics.textures[field.value] = uploadTexture(tile);
  }
}

fn extractTile(dest: *image.Image, source: *const image.Image, tx: u32, ty: u32) void {
  var y: u32 = 0;
  while (y < dest.info.height) : (y += 1) {
    var x: u32 = 0;
    while (x < dest.info.width) : (x += 1) {
      const px = tx * dest.info.width + x;
      const py = ty * dest.info.height + y;
      const pixel = image.getPixel(source, px, py).?;
      image.setPixel(dest, x, y, pixel);
    }
  }
}
