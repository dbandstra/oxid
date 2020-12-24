const std = @import("std");
// FIXME - how come this doesn't work? it worked in platform/draw...
//const HunkSide = @import("zig-hunk").HunkSide;
const HunkSide = @import("../../lib/zig-hunk/hunk.zig").HunkSide;

const datadir = "Oxid";

pub const ReadableObject = struct {
    file: std.fs.File,
    size: usize,

    pub fn open(hunk_side: *HunkSide, key: []const u8) !?ReadableObject {
        const mark = hunk_side.getMark();
        defer hunk_side.freeToMark(mark);

        const dir_path = try std.fs.getAppDataDir(&hunk_side.allocator, datadir);
        const file_path = try std.fs.path.join(&hunk_side.allocator, &[_][]const u8{
            dir_path,
            key,
        });

        const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
            if (err == error.FileNotFound)
                return null;
            return err;
        };
        errdefer file.close();

        return ReadableObject{
            .file = file,
            .size = try std.math.cast(usize, try file.getEndPos()),
        };
    }

    pub fn close(self: ReadableObject) void {
        self.file.close();
    }

    pub fn reader(self: ReadableObject) std.fs.File.Reader {
        return self.file.reader();
    }
};

pub const WritableObject = struct {
    file: std.fs.File,

    pub fn open(hunk_side: *HunkSide, key: []const u8) !WritableObject {
        const mark = hunk_side.getMark();
        defer hunk_side.freeToMark(mark);

        const dir_path = try std.fs.getAppDataDir(&hunk_side.allocator, datadir);

        std.fs.cwd().makeDir(dir_path) catch |err| {
            if (err != error.PathAlreadyExists)
                return err;
        };

        const file_path = try std.fs.path.join(&hunk_side.allocator, &[_][]const u8{
            dir_path,
            key,
        });

        const file = try std.fs.cwd().createFile(file_path, .{});

        return WritableObject{
            .file = file,
        };
    }

    pub fn close(self: WritableObject) void {
        self.file.close();
    }

    pub fn writer(self: WritableObject) std.fs.File.Writer {
        return self.file.writer();
    }
};
