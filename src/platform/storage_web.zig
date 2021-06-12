const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;

// extern functions implemented in javascript
extern fn deleteLocalStorage(name_ptr: [*]const u8, name_len: c_int) void;
extern fn getLocalStorage(name_ptr: [*]const u8, name_len: c_int, value_ptr: [*]const u8, value_maxlen: c_int) c_int;
extern fn setLocalStorage(name_ptr: [*]const u8, name_len: c_int, value_ptr: [*]const u8, value_len: c_int) void;

pub fn deleteObject(hunk_side: *HunkSide, key: []const u8) !void {
    deleteLocalStorage(key.ptr, @intCast(c_int, key.len));
}

pub const ReadableObject = struct {
    buffer: [5000]u8, // FIXME store the buffer outside. ReadableObject should not be heavyweight.
    pos: usize,
    size: usize,

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*ReadableObject, ReadError, read);

    pub fn open(hunk_side: *HunkSide, key: []const u8) !?ReadableObject {
        var buffer: [5000]u8 = undefined;

        const bytes_read = getLocalStorage(
            key.ptr,
            @intCast(c_int, key.len),
            &buffer,
            @intCast(c_int, buffer.len),
        );
        if (bytes_read < 0)
            return error.GetLocalStorageFailed;
        if (bytes_read == 0)
            return null;

        return ReadableObject{
            .buffer = buffer,
            .pos = 0,
            .size = @intCast(usize, bytes_read),
        };
    }

    pub fn close(self: ReadableObject) void {}

    pub fn reader(self: *ReadableObject) Reader {
        return .{ .context = self };
    }

    // implementation copied from std.io.FixedBufferStream
    // can't use std.io.FixedBufferStream because there's no way to get it to
    // point to self.buffer in the open function (since self is returned by
    // value)
    pub fn read(self: *ReadableObject, dest: []u8) ReadError!usize {
        const size = std.math.min(dest.len, self.size - self.pos);
        const end = self.pos + size;

        std.mem.copy(u8, dest[0..size], self.buffer[self.pos..end]);
        self.pos = end;

        return size;
    }
};

pub const WritableObject = struct {
    key: []const u8,
    buffer: [5000]u8, // FIXME
    pos: usize,

    pub const WriteError = error{NoSpaceLeft};
    pub const SeekError = error{};
    pub const GetSeekPosError = error{};

    pub const Writer = std.io.Writer(*WritableObject, WriteError, write);
    pub const SeekableStream = std.io.SeekableStream(
        *WritableObject,
        SeekError,
        GetSeekPosError,
        seekTo,
        seekBy,
        getPos,
        getEndPos,
    );

    pub fn open(hunk_side: *HunkSide, key: []const u8) !WritableObject {
        return WritableObject{
            .key = key,
            .buffer = undefined,
            .pos = 0,
        };
    }

    pub fn close(self: WritableObject) void {
        setLocalStorage(
            self.key.ptr,
            @intCast(c_int, self.key.len),
            &self.buffer,
            @intCast(c_int, self.pos),
        );
    }

    pub fn writer(self: *WritableObject) Writer {
        return .{ .context = self };
    }

    pub fn seekableStream(self: *WritableObject) SeekableStream {
        return .{ .context = self };
    }

    // implementation copied from std.io.FixedBufferStream
    pub fn write(self: *WritableObject, bytes: []const u8) WriteError!usize {
        if (bytes.len == 0) return 0;
        if (self.pos >= self.buffer.len) return error.NoSpaceLeft;

        const n = if (self.pos + bytes.len <= self.buffer.len)
            bytes.len
        else
            self.buffer.len - self.pos;

        std.mem.copy(u8, self.buffer[self.pos .. self.pos + n], bytes[0..n]);
        self.pos += n;

        if (n == 0) return error.NoSpaceLeft;

        return n;
    }

    pub fn seekTo(self: *WritableObject, pos: u64) SeekError!void {
        self.pos = if (std.math.cast(usize, pos)) |x| x else |_| self.buffer.len;
    }

    pub fn seekBy(self: *WritableObject, amt: i64) SeekError!void {
        if (amt < 0) {
            const abs_amt = std.math.absCast(amt);
            const abs_amt_usize = std.math.cast(usize, abs_amt) catch std.math.maxInt(usize);
            if (abs_amt_usize > self.pos) {
                self.pos = 0;
            } else {
                self.pos -= abs_amt_usize;
            }
        } else {
            const amt_usize = std.math.cast(usize, amt) catch std.math.maxInt(usize);
            const new_pos = std.math.add(usize, self.pos, amt_usize) catch std.math.maxInt(usize);
            self.pos = std.math.min(self.buffer.len, new_pos);
        }
    }

    pub fn getEndPos(self: *WritableObject) GetSeekPosError!u64 {
        return self.buffer.len;
    }

    pub fn getPos(self: *WritableObject) GetSeekPosError!u64 {
        return self.pos;
    }
};
