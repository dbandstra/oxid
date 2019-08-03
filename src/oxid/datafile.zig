const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const Constants = @import("constants.zig");

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

pub fn loadHighScores(hunk_side: *HunkSide) ![Constants.num_high_scores]u32 {
    const file = openDataFile(hunk_side, "highscore.dat", .Read) catch |err| {
        if (err == error.FileNotFound) {
            return [1]u32{0} ** Constants.num_high_scores;
        }
        return err;
    };
    defer file.close();

    var fis = std.fs.File.inStream(file);

    var high_scores = [1]u32{0} ** Constants.num_high_scores;
    var i: usize = 0; while (i < Constants.num_high_scores) : (i += 1) {
        high_scores[i] = fis.stream.readIntLittle(u32) catch 0;
    }
    return high_scores;
}

pub fn saveHighScores(hunk_side: *HunkSide, high_scores: [Constants.num_high_scores]u32) !void {
    const file = try openDataFile(hunk_side, "highscore.dat", .Write);
    defer file.close();

    var fos = std.fs.File.outStream(file);

    for (high_scores) |score| {
        try fos.stream.writeIntLittle(u32, score);
    }
}
