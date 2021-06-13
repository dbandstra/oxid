const std = @import("std");
const cc = @cImport({
    @cInclude("time.h");
});

pub fn getDateTime(writer: anytype) !void {
    var t = cc.time(null);
    var tm: *cc.tm = cc.localtime(&t) orelse return error.FailedToGetLocalTime;

    try writer.print("{d:0>4}-{d:0>2}-{d:0>2}_{d:0>2}-{d:0>2}-{d:0>2}", .{
        // cast to unsigned because zig is weird and prints '+' characters
        // before all signed numbers
        (try std.math.cast(u32, tm.tm_year)) + 1900,
        (try std.math.cast(u32, tm.tm_mon)) + 1,
        try std.math.cast(u32, tm.tm_mday),
        try std.math.cast(u32, tm.tm_hour),
        try std.math.cast(u32, tm.tm_min),
        try std.math.cast(u32, tm.tm_sec),
    });
}
