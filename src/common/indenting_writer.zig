const std = @import("std");

pub fn IndentingWriter(comptime T: type) type {
    return struct {
        indentation: usize,
        dest: T,
        new_line: bool = true,

        pub const Error = T.Error;
        pub const Writer = std.io.Writer(*@This(), T.Error, write);

        pub fn writer(self: *@This()) Writer {
            return .{ .context = self };
        }

        pub fn write(context: *@This(), bytes: []const u8) Error!usize {
            for (bytes) |byte| {
                if (context.new_line)
                    try context.dest.writeByteNTimes(' ', context.indentation);
                try context.dest.writeByte(byte);
                context.new_line = byte == '\n';
            }
            return bytes.len;
        }
    };
}

pub fn indentingWriter(dest: anytype, indentation: usize) IndentingWriter(@TypeOf(dest)) {
    return IndentingWriter(@TypeOf(dest)){
        .dest = dest,
        .indentation = indentation,
    };
}
