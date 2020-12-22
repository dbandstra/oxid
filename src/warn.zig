const builtin = @import("builtin");
const std = @import("std");

pub const warn = if (builtin.arch == .wasm32)
    warnWeb
else
    std.debug.warn;

fn warnWeb(comptime fmt: []const u8, args: anytype) void {
    const web = @import("web.zig");

    var buf: [1000]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, fmt, args) catch {
        web.consoleLog("warn: bufPrint failed. too long? format string:");
        web.consoleLog(fmt);
        return;
    };
    web.consoleLog(text);
}
