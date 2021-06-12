const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;

const dirname = @import("root").pstorage_dirname;

pub fn deleteObject(hunk_side: *HunkSide, key: []const u8) !void {
    const mark = hunk_side.getMark();
    defer hunk_side.freeToMark(mark);

    const dir_path = try std.fs.getAppDataDir(&hunk_side.allocator, dirname);
    const file_path = try std.fs.path.join(&hunk_side.allocator, &[_][]const u8{
        dir_path,
        key,
    });

    for (file_path) |*ch| {
        if (ch.* == '/')
            ch.* = std.fs.path.sep;
    }

    try std.fs.cwd().deleteFile(file_path);
}

pub const ReadableObject = struct {
    file: std.fs.File,
    size: usize,

    pub const Reader = std.fs.File.Reader;

    pub fn open(hunk_side: *HunkSide, key: []const u8) !?ReadableObject {
        const mark = hunk_side.getMark();
        defer hunk_side.freeToMark(mark);

        const dir_path = try std.fs.getAppDataDir(&hunk_side.allocator, dirname);
        const file_path = try std.fs.path.join(&hunk_side.allocator, &[_][]const u8{
            dir_path,
            key,
        });

        for (file_path) |*ch| {
            if (ch.* == '/')
                ch.* = std.fs.path.sep;
        }

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

    pub fn reader(self: *ReadableObject) Reader {
        return self.file.reader();
    }
};

pub const WritableObject = struct {
    file: std.fs.File,

    pub const Writer = std.fs.File.Writer;
    pub const SeekableStream = std.fs.File.SeekableStream;

    pub fn open(hunk_side: *HunkSide, key: []const u8) !WritableObject {
        const mark = hunk_side.getMark();
        defer hunk_side.freeToMark(mark);

        const dir_path = try std.fs.getAppDataDir(&hunk_side.allocator, dirname);

        // make the `dirname` if it doesn't exist
        std.fs.cwd().makeDir(dir_path) catch |err| {
            if (err != error.PathAlreadyExists)
                return err;
        };

        const file_path = try std.fs.path.join(&hunk_side.allocator, &[_][]const u8{
            dir_path,
            key,
        });

        // if the storagekey contains slashes, make the subdirectories
        var i = dir_path.len + 1;
        while (true) {
            const rel_pos = std.mem.indexOfScalar(u8, file_path[i..], '/') orelse break;
            const abs_pos = i + rel_pos;

            file_path[abs_pos] = std.fs.path.sep; // convert to backslash on windows

            const subdirname = file_path[0..abs_pos];

            std.fs.cwd().makeDir(subdirname) catch |err| {
                if (err != error.PathAlreadyExists)
                    return err;
            };

            i = abs_pos + 1;
        }

        const file = try std.fs.cwd().createFile(file_path, .{});

        return WritableObject{
            .file = file,
        };
    }

    pub fn close(self: WritableObject) void {
        self.file.close();
    }

    pub fn writer(self: *WritableObject) Writer {
        return self.file.writer();
    }

    pub fn seekableStream(self: *WritableObject) SeekableStream {
        return self.file.seekableStream();
    }
};
