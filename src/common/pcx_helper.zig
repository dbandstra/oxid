const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const pcx = @import("zig-pcx");

pub const LoadPcxError = error{
    PcxLoadFailed,
    EndOfStream,
    OutOfMemory,
};

pub const PcxImage = struct {
    pixels: []u8, // r8g8b8a8 format
    width: u32,
    height: u32,
    palette: [48]u8, // 16 colors
};

pub fn loadPcx(
    hunk_side: *HunkSide,
    comptime filename: []const u8,
    transparent_color_index: ?u8,
) LoadPcxError!PcxImage {
    const filedata = @embedFile(filename);

    var fbs = std.io.fixedBufferStream(filedata);
    var stream = fbs.inStream();
    const Loader = pcx.Loader(@TypeOf(stream));

    // load PCX header
    const preloaded = try Loader.preload(&stream);

    // allocate space for image data
    const width: u32 = preloaded.width;
    const height: u32 = preloaded.height;

    const pixels = try hunk_side.allocator.alloc(u8, width * height * 4);
    var palette: [768]u8 = undefined;

    // decode image into `pixels`
    try Loader.loadIndexedWithStride(&stream, preloaded, pixels, 4, &palette);

    // convert image data to RGBA
    var i: u32 = 0;
    while (i < width * height) : (i += 1) {
        const index: usize = pixels[i * 4 + 0];
        pixels[i * 4 + 0] = palette[index * 3 + 0];
        pixels[i * 4 + 1] = palette[index * 3 + 1];
        pixels[i * 4 + 2] = palette[index * 3 + 2];
        pixels[i * 4 + 3] =
            if ((transparent_color_index orelse ~index) == index) 0 else 255;
    }

    return PcxImage{
        .pixels = pixels,
        .width = width,
        .height = height,
        .palette = palette[0..48].*,
    };
}
