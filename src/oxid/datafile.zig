const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;

const Mode = enum {
    Read,
    Write,
};

fn openDataFile(hunk_side: *HunkSide, filename: []const u8, mode: Mode) !std.fs.File {
    const mark = hunk_side.getMark();
    defer hunk_side.freeToMark(mark);

    const dir_path = try std.fs.getAppDataDir(&hunk_side.allocator, "Oxid");

    if (mode == .Write) {
        std.fs.makeDir(dir_path) catch |err| {
            if (err != error.PathAlreadyExists) {
                return err;
            }
        };
    }

    const file_path = try std.fs.path.join(&hunk_side.allocator, [_][]const u8{dir_path, filename});

    return switch (mode) {
        .Read => std.fs.File.openRead(file_path),
        .Write => std.fs.File.openWrite(file_path),
    };
}

pub fn loadHighScore(hunk_side: *HunkSide) !u32 {
    const file = openDataFile(hunk_side, "highscore.dat", .Read) catch |err| {
        if (err == error.FileNotFound) {
            return u32(0);
        }
        return err;
    };
    defer file.close();

    var fis = std.fs.File.inStream(file);

    return fis.stream.readIntLittle(u32);
}

pub fn saveHighScore(hunk_side: *HunkSide, high_score: u32) !void {
    const file = try openDataFile(hunk_side, "highscore.dat", .Write);
    defer file.close();

    var fos = std.fs.File.outStream(file);

    try fos.stream.writeIntLittle(u32, high_score);
}
