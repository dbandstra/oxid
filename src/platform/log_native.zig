const std = @import("std");

pub const warn = std.debug.warn;

pub fn warnWriter() std.fs.File.Writer {
    return std.io.getStdErr().writer();
}

pub fn flushWarnWriter() void {}
