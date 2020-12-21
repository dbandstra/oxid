const std = @import("std");

// zig implementation of the following shell command:
//
// (git describe --tags 2>/dev/null || echo no-version) > zig-cache/version.txt

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();

    var allocator = &gpa.allocator;

    const outfile = try std.fs.cwd().createFile("zig-cache/version.txt", .{});
    defer outfile.close();
    var outfilestream = outfile.writer();

    const argv = &[_][]const u8{ "git", "describe", "--tags" };
    const child = try std.ChildProcess.init(argv, allocator);
    defer child.deinit();

    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    const stream = child.stdout.?.reader();

    var buffer: [64]u8 = undefined;
    while (true) {
        const n = try stream.read(&buffer);
        if (n == 0) break;
        try outfilestream.writeAll(buffer[0..n]);
    }

    const code = switch (try child.wait()) {
        .Exited => |code| code,
        else => return error.UncleanExit,
    };
    if (code != 0) try outfilestream.writeAll("no-version\n");
}
