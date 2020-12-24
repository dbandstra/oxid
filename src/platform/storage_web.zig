const std = @import("std");
// FIXME - how come this doesn't work? it worked in platform/draw...
//const HunkSide = @import("zig-hunk").HunkSide;
const HunkSide = @import("../../lib/zig-hunk/hunk.zig").HunkSide;
const web = @import("../web.zig");

const datadir = "Oxid";

pub const ReadableObject = struct {
    buffer: [5000]u8,
    pos: usize,
    size: usize,

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*ReadableObject, ReadError, read);

    pub fn init(hunk_side: *HunkSide, key: []const u8) !?ReadableObject {
        var buffer: [5000]u8 = undefined;

        const bytes_read = try web.getLocalStorage(key, &buffer);
        if (bytes_read == 0)
            return null;

        return ReadableObject{
            .buffer = buffer,
            .pos = 0,
            .size = bytes_read,
        };
    }

    pub fn deinit(self: ReadableObject) void {}

    pub fn reader(self: *ReadableObject) Reader {
        return Reader{ .context = self };
    }

    // can't use std.io.FixedBufferStream because there's no way to get it to
    // point to self.buffer in the init function (since self is returned by
    // value)
    pub fn read(self: *ReadableObject, dest: []u8) ReadError!usize {
        const size = std.math.min(dest.len, self.size - self.pos);
        const end = self.pos + size;

        std.mem.copy(u8, dest[0..size], self.buffer[self.pos..end]);
        self.pos = end;

        return size;
    }
};

//pub const WritableObject = struct {
//    file: std.fs.File,
//
//    pub fn init(hunk_side: *HunkSide, key: []const u8) !WritableObject {
//        const mark = hunk_side.getMark();
//        defer hunk_side.freeToMark(mark);
//
//        const dir_path = try std.fs.getAppDataDir(&hunk_side.allocator, datadir);
//
//        std.fs.cwd().makeDir(dir_path) catch |err| {
//            if (err != error.PathAlreadyExists)
//                return err;
//        };
//
//        const file_path = try std.fs.path.join(&hunk_side.allocator, &[_][]const u8{
//            dir_path,
//            key,
//        });
//
//        const file = try std.fs.cwd().createFile(file_path, .{});
//
//        return WritableObject{
//            .file = file,
//        };
//    }
//
//    pub fn deinit(self: WritableObject) void {
//        self.file.close();
//    }
//
//    pub fn writer(self: WritableObject) std.fs.File.Writer {
//        return self.file.writer();
//    }
//};

//pub fn saveConfig(cfg: config.Config) !void {
//    var buffer: [5000]u8 = undefined;
//    var dest = std.io.SliceOutStream.init(buffer[0..]);
//    try config.write(std.io.SliceOutStream.Error, &dest.stream, cfg);
//    web.setLocalStorage(config_storagekey, dest.getWritten());
//}
