const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;

const assets_path = @import("build_options").assets_path;

// load an asset into memory. (decided against a stream API because in the web
// implementation, the asset is already in memory so this saves storing two
// copies in memory in the case that the asset can be used uncompressed, e.g.
// wav files.
pub fn loadAsset(
    allocator: *std.mem.Allocator, // return value is allocated using this
    hunk_side: *HunkSide, // for temporary allocation
    filename: []const u8,
) ![]const u8 {
    const mark = hunk_side.getMark();
    defer hunk_side.freeToMark(mark);

    const file_path = try std.fs.path.join(&hunk_side.allocator, &[_][]const u8{
        assets_path,
        filename,
    });

    const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
        if (err == error.FileNotFound)
            return error.AssetNotFound;
        return err;
    };
    defer file.close();

    const size = try std.math.cast(usize, try file.getEndPos());

    var contents = try allocator.alloc(u8, size);

    const bytes_read = try file.readAll(contents);
    if (bytes_read != size)
        return error.ReadFailed;

    return contents;
}
