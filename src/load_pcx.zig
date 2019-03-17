const std = @import("std");
const HunkSide = @import("zigutils").HunkSide;
const pcx = @import("zig-pcx");

pub const LoadPcxError = error{
  PcxLoadFailed,
  EndOfStream,
  OutOfMemory,
};

pub const Image = struct{
  pixels: []u8, // r8g8b8a8 format
  width: u32,
  height: u32,
};

pub fn loadPcx(
  hunk_side: *HunkSide,
  comptime filename: []const u8,
  transparent_color_index: ?u8,
) LoadPcxError!Image {
  const filedata = @embedFile(filename);

  var slice_stream = std.io.SliceInStream.init(filedata);
  var stream = &slice_stream.stream;
  const Loader = pcx.Loader(std.io.SliceInStream.Error);

  // load PCX header
  const preloaded = try Loader.preload(stream);

  // allocate space for image data
  const pixels = try hunk_side.allocator.alloc(u8, preloaded.width * preloaded.height * 4);

  // decode image into `pixels`
  try Loader.loadRGBA(stream, preloaded, transparent_color_index, pixels);

  return Image{
    .pixels = pixels,
    .width = preloaded.width,
    .height = preloaded.height,
  };
}
