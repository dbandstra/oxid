const builtin = @import("builtin");
const std = @import("std");

// extern functions implemented in javascript
extern fn consoleLog(message_ptr: [*]const u8, message_len: c_uint) void;

fn logLine(message: []const u8) void {
    consoleLog(message.ptr, message.len);
}

pub fn warn(comptime fmt: []const u8, args: anytype) void {
    var buf: [1000]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, fmt, args) catch {
        logLine("warn: bufPrint failed. too long? format string:");
        logLine(fmt);
        return;
    };
    logLine(text);
}

const WriteError = error{};

pub fn warnWriter() std.io.Writer(void, WriteError, write) {
    return std.io.Writer(void, WriteError, write){ .context = {} };
}

var warn_writer_buffer: [256]u8 = undefined;
var warn_writer_index: usize = 0;

fn write(self: void, bytes: []const u8) WriteError!usize {
    for (bytes) |byte| {
        if (warn_writer_index < warn_writer_buffer.len) {
            warn_writer_buffer[warn_writer_index] = byte;
            warn_writer_index += 1;
        }
    }
    return bytes.len;
}

pub fn flushWarnWriter() void {
    if (warn_writer_index > 0) {
        logLine(warn_writer_buffer[0..warn_writer_index]);
        warn_writer_index = 0;
    }
}
