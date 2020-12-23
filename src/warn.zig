const builtin = @import("builtin");
const std = @import("std");

pub const warn = if (builtin.arch == .wasm32)
    warnWeb
else
    std.debug.warn;

pub const warnWriter = if (builtin.arch == .wasm32)
    warnWriterWeb
else
    warnWriterNative;

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

// FIXME apparently error{} is not compatible with error{}, so i need a named decl
const Error = error{};

fn warnWriterWeb() std.io.Writer(void, Error, write) {
    return std.io.Writer(void, Error, write){ .context = {} };
}

fn warnWriterNative() std.fs.File.Writer {
    return std.io.getStdErr().writer();
}

var warn_writer_buffer: [256]u8 = undefined;
var warn_writer_index: usize = 0;

fn write(self: void, bytes: []const u8) error{}!usize {
    for (bytes) |byte| {
        if (warn_writer_index < warn_writer_buffer.len) {
            warn_writer_buffer[warn_writer_index] = byte;
            warn_writer_index += 1;
        }
    }
    return bytes.len;
}

pub fn flushWarnWriter() void {
    if (builtin.arch == .wasm32) {
        const web = @import("web.zig");

        if (warn_writer_index > 0) {
            web.consoleLog(warn_writer_buffer[0..warn_writer_index]);
            warn_writer_index = 0;
        }
    }
}
