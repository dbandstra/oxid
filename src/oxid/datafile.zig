const std = @import("std");
const Constants = @import("constants.zig");

pub fn readHighScores(comptime ReadError: type, stream: *std.io.InStream(ReadError)) [Constants.num_high_scores]u32 {
    var high_scores = [1]u32{0} ** Constants.num_high_scores;
    var i: usize = 0; while (i < Constants.num_high_scores) : (i += 1) {
        high_scores[i] = stream.readIntLittle(u32) catch 0;
    }
    return high_scores;
}

pub fn writeHighScores(comptime WriteError: type, stream: *std.io.OutStream(WriteError), high_scores: [Constants.num_high_scores]u32) !void {
    for (high_scores) |score| {
        try stream.writeIntLittle(u32, score);
    }
}
