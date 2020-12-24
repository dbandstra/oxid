const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;

// extern functions implemented in javascript
extern fn getAsset(name_ptr: [*]const u8, name_len: c_int, result_addr_ptr: *[*]const u8, result_addr_len_ptr: *c_int) bool;

pub fn loadAsset(
    allocator: *std.mem.Allocator, // not used
    hunk_side: *HunkSide, // not used
    filename: []const u8,
) ![]const u8 {
    // in the web build, assets are preloaded on the javascript side, and put
    // into program memory, where they live permanently. we just retrieve a
    // pointer to the asset data here.
    // TODO - consider allowing the zig side to "consume" an asset which should
    // free it on the js side. this would be useful for assets that need to be
    // decompressed or otherwise processed.
    var ptr: [*]const u8 = undefined;
    var len: c_int = undefined;
    if (!getAsset(filename.ptr, @intCast(c_int, filename.len), &ptr, &len))
        return error.AssetNotFound;

    return ptr[0..@intCast(usize, len)];
}
