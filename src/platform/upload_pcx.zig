const std = @import("std");
const DoubleStackAllocatorFlat = @import("../../zigutils/src/DoubleStackAllocatorFlat.zig").DoubleStackAllocatorFlat;
const image = @import("../../zigutils/src/image/image.zig");
const pcx = @import("../../zig-comptime-pcx/pcx.zig");

const Draw = @import("../draw.zig");
const Platform = @import("../platform/platform.zig");

// frees everything it allocates
pub fn uploadPcx(
  dsaf: *DoubleStackAllocatorFlat,
  comptime filename: []const u8,
  transparent_color_index: ?u8,
) !Platform.Texture {
  const low_mark = dsaf.get_low_mark();
  defer dsaf.free_to_low_mark(low_mark);

  const filedata = @embedFile(filename);

  var slice_stream = std.io.SliceInStream.init(filedata);
  var stream = &slice_stream.stream;
  const Loader = pcx.Loader(std.io.SliceInStream.Error);

  const preloaded = try Loader.preload(stream);
  const img = try image.createImage(&dsaf.low_allocator, image.Info{
    .width = preloaded.width,
    .height = preloaded.height,
    .format = image.Format.RGBA,
  });
  try Loader.loadRGBA(stream, &preloaded, transparent_color_index, img.pixels);

  return Platform.uploadTexture(img);
}
