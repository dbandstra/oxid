const std = @import("std");
const DoubleStackAllocatorFlat = @import("../../zigutils/src/DoubleStackAllocatorFlat.zig").DoubleStackAllocatorFlat;
const image = @import("../../zigutils/src/image/image.zig");
const pcx = @import("../../zig-comptime-pcx/pcx.zig");

const Platform = @import("../platform/platform.zig");

const GRAPHICS_FILENAME = @import("graphics_config.zig").GRAPHICS_FILENAME;
const TRANSPARENT_COLOR_INDEX = @import("graphics_config.zig").TRANSPARENT_COLOR_INDEX;
const Graphic = @import("graphics_config.zig").Graphic;
const getGraphicConfig = @import("graphics_config.zig").getGraphicConfig;

pub const Graphics = struct{
  background_colour: image.Pixel,
  textures: [@memberCount(Graphic)]Platform.Texture,

  pub fn texture(self: *Graphics, graphic: Graphic) *Platform.Texture {
    return &self.textures[@enumToInt(graphic)];
  }
};

// return an Image allocated in the low_allocator
fn loadTileset(dsaf: *DoubleStackAllocatorFlat) !*image.Image {
  const filedata = @embedFile(GRAPHICS_FILENAME);

  var slice_stream = std.io.SliceInStream.init(filedata);
  var stream = &slice_stream.stream;
  const Loader = pcx.Loader(std.io.SliceInStream.Error);

  // load pcx
  const preloaded = try Loader.preload(stream);
  const img = try image.createImage(&dsaf.low_allocator, image.Info{
    .width = preloaded.width,
    .height = preloaded.height,
    .format = image.Format.RGBA,
  });
  try Loader.loadRGBA(stream, &preloaded, TRANSPARENT_COLOR_INDEX, img.pixels);

  return img;
}

pub fn loadGraphics(dsaf: *DoubleStackAllocatorFlat, graphics: *Graphics) !void {
  const low_mark = dsaf.get_low_mark();
  defer dsaf.free_to_low_mark(low_mark);

  const tileset = try loadTileset(dsaf);

  const tile = try image.createImage(&dsaf.low_allocator, image.Info{
    .width = 16,
    .height = 16,
    .format = image.Format.RGBA,
  });

  for (@typeInfo(Graphic).Enum.fields) |field| {
    const graphic = @intToEnum(Graphic, @intCast(@typeInfo(Graphic).Enum.tag_type, field.value));
    const config = getGraphicConfig(graphic);
    extractTile(tile, tileset, config.tx, config.ty);
    graphics.textures[field.value] = Platform.uploadTexture(tile);
  }
}

fn extractTile(dest: *image.Image, source: *const image.Image, tx: u32, ty: u32) void {
  var y: u32 = 0;
  while (y < dest.info.height) : (y += 1) {
    var x: u32 = 0;
    while (x < dest.info.width) : (x += 1) {
      const px = tx * dest.info.width + x;
      const py = ty * dest.info.height + y;
      if (image.getPixel(source, px, py)) |pixel| {
        image.setPixel(dest, x, y, pixel);
      } else {
        image.setPixel(dest, x, y, image.Pixel{ .r = 0, .g = 0, .b = 0, .a = 0 });
      }
    }
  }
}
