const std = @import("std");
const Allocator = std.mem.Allocator;

const DoubleStackAllocatorFlat = @import("../zigutils/src/DoubleStackAllocatorFlat.zig").DoubleStackAllocatorFlat;
const MemoryInStream = @import("../zigutils/src/MemoryInStream.zig").MemoryInStream;
const Image = @import("../zigutils/src/image/image.zig").Image;
const ImageFormat = @import("../zigutils/src/image/image.zig").ImageFormat;
const ImageInfo = @import("../zigutils/src/image/image.zig").ImageInfo;
const Pixel = @import("../zigutils/src/image/image.zig").Pixel;
const allocImage = @import("../zigutils/src/image/image.zig").allocImage;
const allocImagePalette = @import("../zigutils/src/image/image.zig").allocImagePalette;
const getColor = @import("../zigutils/src/image/image.zig").getColor;
const LoadPcx = @import("../zigutils/src/image/pcx.zig").LoadPcx;
const pcxBestStoreFormat = @import("../zigutils/src/image/pcx.zig").pcxBestStoreFormat;

const convertToTrueColor = @import("imagefuncs.zig").convertToTrueColor;
const extract_tile = @import("imagefuncs.zig").extract_tile;
const flip_image_horizontal = @import("imagefuncs.zig").flip_image_horizontal;

const Texture = @import("main.zig").Texture;
const upload_texture = @import("main.zig").upload_texture;

pub const Graphic = enum{
  Pit,
  PlaBullet,
  PlaSpark1,
  PlaSpark2,
  MonBullet,
  MonSpark1,
  MonSpark2,
  Floor,
  Man1,
  Man2,
  Skeleton,
  Wall,
  Wall2,
  Spider1,
  Spider2,
  Explode1,
  Explode2,
  Explode3,
  Explode4,
  Spawn1,
  Spawn2,
  Squid1,
  Squid2,
};

const GraphicConfig = struct{
  tx: u32,
  ty: u32,
  fliph: bool,
};

fn getGraphicConfig(graphic: Graphic) GraphicConfig {
  return switch (graphic) {
    Graphic.Pit       => GraphicConfig{ .tx = 1, .ty = 1, .fliph = false },
    Graphic.PlaBullet => GraphicConfig{ .tx = 2, .ty = 2, .fliph = true },
    Graphic.PlaSpark1 => GraphicConfig{ .tx = 1, .ty = 2, .fliph = true },
    Graphic.PlaSpark2 => GraphicConfig{ .tx = 0, .ty = 2, .fliph = true },
    Graphic.MonBullet => GraphicConfig{ .tx = 2, .ty = 4, .fliph = true },
    Graphic.MonSpark1 => GraphicConfig{ .tx = 1, .ty = 4, .fliph = true },
    Graphic.MonSpark2 => GraphicConfig{ .tx = 0, .ty = 4, .fliph = true },
    Graphic.Floor     => GraphicConfig{ .tx = 4, .ty = 1, .fliph = false },
    Graphic.Man1      => GraphicConfig{ .tx = 3, .ty = 2, .fliph = true },
    Graphic.Man2      => GraphicConfig{ .tx = 4, .ty = 2, .fliph = true },
    Graphic.Skeleton  => GraphicConfig{ .tx = 6, .ty = 2, .fliph = true },
    Graphic.Wall,
    Graphic.Wall2     => GraphicConfig{ .tx = 5, .ty = 1, .fliph = false },
    Graphic.Spider1   => GraphicConfig{ .tx = 3, .ty = 3, .fliph = true },
    Graphic.Spider2   => GraphicConfig{ .tx = 4, .ty = 3, .fliph = true },
    Graphic.Explode1  => GraphicConfig{ .tx = 5, .ty = 3, .fliph = false },
    Graphic.Explode2  => GraphicConfig{ .tx = 6, .ty = 3, .fliph = false },
    Graphic.Explode3  => GraphicConfig{ .tx = 7, .ty = 3, .fliph = false },
    Graphic.Explode4  => GraphicConfig{ .tx = 8, .ty = 3, .fliph = false },
    Graphic.Spawn1    => GraphicConfig{ .tx = 2, .ty = 3, .fliph = false },
    Graphic.Spawn2    => GraphicConfig{ .tx = 1, .ty = 3, .fliph = false },
    Graphic.Squid1    => GraphicConfig{ .tx = 3, .ty = 4, .fliph = true },
    Graphic.Squid2    => GraphicConfig{ .tx = 4, .ty = 4, .fliph = true },
  };
}

pub const SimpleAnim = enum{
  PlaSparks,
  MonSparks,
  Explosion,
};

pub const SimpleAnimConfig = struct{
  frames: []const Graphic,
  ticks_per_frame: u32,
};

pub fn getSimpleAnim(simpleAnim: SimpleAnim) SimpleAnimConfig {
  return switch (simpleAnim) {
    SimpleAnim.PlaSparks => SimpleAnimConfig{
      .frames = ([2]Graphic{
        Graphic.PlaSpark1,
        Graphic.PlaSpark2,
      })[0..],
      .ticks_per_frame = 4,
    },
    SimpleAnim.MonSparks => SimpleAnimConfig{
      .frames = ([2]Graphic{
        Graphic.MonSpark1,
        Graphic.MonSpark2,
      })[0..],
      .ticks_per_frame = 4,
    },
    SimpleAnim.Explosion => SimpleAnimConfig{
      .frames = ([4]Graphic{
        Graphic.Explode1,
        Graphic.Explode2,
        Graphic.Explode3,
        Graphic.Explode4,
      })[0..],
      .ticks_per_frame = 4,
    }
  };
}

pub const Graphics = struct{
  background_colour: Pixel,
  textures: [@memberCount(Graphic)]Texture,

  pub fn texture(self: *Graphics, graphic: Graphic) *Texture {
    return &self.textures[@enumToInt(graphic)];
  }
};

// return an Image allocated in the low_allocator
fn load_tileset(dsaf: *DoubleStackAllocatorFlat, out_background_colour: *Pixel) !*Image {
  const high_mark = dsaf.get_high_mark();
  defer dsaf.free_to_high_mark(high_mark);

  const filename = "../assets/mytiles.pcx";
  const TRANSPARENT_COLOR_INDEX = 12;

  var source = MemoryInStream.init(@embedFile(filename));

  // load pcx
  const pcxInfo = try LoadPcx(MemoryInStream.ReadError).preload(&source.stream, &source.seekable);
  const image = try allocImage(&dsaf.high_allocator, ImageInfo{
    .width = pcxInfo.width,
    .height = pcxInfo.height,
    .format = pcxBestStoreFormat(pcxInfo),
  });
  try LoadPcx(MemoryInStream.ReadError).load(&source.stream, &source.seekable, pcxInfo, image);

  // load palette
  const palette = try allocImagePalette(&dsaf.high_allocator);
  try LoadPcx(MemoryInStream.ReadError).loadPalette(&source.stream, &source.seekable, pcxInfo, palette);

  // convert to true color image
  const image2 = try allocImage(&dsaf.low_allocator, ImageInfo{
    .width = image.info.width,
    .height = image.info.height,
    .format = ImageFormat.RGBA,
  });
  convertToTrueColor(image2, image, palette, TRANSPARENT_COLOR_INDEX);

  out_background_colour.* = getColor(palette.format, palette.data, TRANSPARENT_COLOR_INDEX);

  return image2;
}

pub fn load_graphics(dsaf: *DoubleStackAllocatorFlat, graphics: *Graphics) !void {
  const low_mark = dsaf.get_low_mark();
  defer dsaf.free_to_low_mark(low_mark);

  const tileset = try load_tileset(dsaf, &graphics.background_colour);

  const tile = try allocImage(&dsaf.low_allocator, ImageInfo{
    .width = 16,
    .height = 16,
    .format = ImageFormat.RGBA,
  });

  for (@typeInfo(Graphic).Enum.fields) |field| {
    const graphic = @intToEnum(Graphic, @intCast(@typeInfo(Graphic).Enum.tag_type, field.value));
    const config = getGraphicConfig(graphic);
    extract_tile(tile, tileset, config.tx, config.ty);
    if (config.fliph) {
      flip_image_horizontal(tile);
    }
    graphics.textures[field.value] = upload_texture(tile);
  }
}
