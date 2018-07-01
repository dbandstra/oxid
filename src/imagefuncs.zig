const std = @import("std");

const Image = @import("../zigutils/src/image/image.zig").Image;
const ImageFormat = @import("../zigutils/src/image/image.zig").ImageFormat;
const ImagePalette = @import("../zigutils/src/image/image.zig").ImagePalette;
const Pixel = @import("../zigutils/src/image/image.zig").Pixel;
const getColor = @import("../zigutils/src/image/image.zig").getColor;
const getPixel = @import("../zigutils/src/image/image.zig").getPixel;

pub fn setPixel(image: *Image, x: u32, y: u32, pixel: Pixel) void {
  if (x < image.info.width and y < image.info.height) {
    return setColor(image.info.format, image.pixels, y * image.info.width + x, pixel);
  }
}

pub fn setColor(format: ImageFormat, data: []u8, ofs: usize, p: Pixel) void {
  switch (format) {
    ImageFormat.RGBA => {
      const mem = data[ofs * 4..ofs * 4 + 4];
      mem[0] = p.r;
      mem[1] = p.g;
      mem[2] = p.b;
      mem[3] = p.a;
    },
    ImageFormat.RGB => {
      const mem = data[ofs * 3..ofs * 3 + 3];
      mem[0] = p.r;
      mem[1] = p.g;
      mem[2] = p.b;
    },
    ImageFormat.INDEXED => {
      unreachable;
    },
  }
}

pub fn extract_tile(dest: *Image, source: *const Image, tx: u32, ty: u32) void {
  var y: u32 = 0;
  while (y < dest.info.height) : (y += 1) {
    var x: u32 = 0;
    while (x < dest.info.width) : (x += 1) {
      const px = tx * dest.info.width + x;
      const py = ty * dest.info.height + y;
      const pixel = getPixel(source, px, py).?;
      setPixel(dest, x, y, pixel);
    }
  }
}

pub fn flip_image_horizontal(image: *Image) void {
  var y: u32 = 0;
  while (y < image.info.height) : (y += 1) {
    var x0: u32 = 0;
    while (x0 < @divTrunc(image.info.width, 2)) : (x0 += 1) {
      const x1 = image.info.width - 1 - x0;
      const p0 = getPixel(image, x0, y).?;
      const p1 = getPixel(image, x1, y).?;
      setPixel(image, x0, y, p1);
      setPixel(image, x1, y, p0);
    }
  }
}

// copied from zigutils and added transparency support
pub fn convertToTrueColor(
  dest: *Image,
  source: *const Image,
  sourcePalette: *const ImagePalette,
  transparent_color_index: ?u32,
) void {
  std.debug.assert(dest.info.width == source.info.width);
  std.debug.assert(dest.info.height == source.info.height);

  var i: usize = 0;
  while (i < dest.info.width * dest.info.height) : (i += 1) {
    const index = source.pixels[i];
    if (transparent_color_index) |t| {
      if (index == t) {
        setColor(dest.info.format, dest.pixels, i, Pixel{
          .r = 0,
          .g = 0,
          .b = 0,
          .a = 0,
        });
        continue;
      }
    }
    const p = getColor(sourcePalette.format, sourcePalette.data, index);
    setColor(dest.info.format, dest.pixels, i, p);
  }
}
