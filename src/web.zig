const builtin = @import("builtin");

pub usingnamespace @import("web/webgl.zig");
pub usingnamespace @import("web/webgl_generated.zig");

pub extern fn getRandomSeed() c_uint;

extern fn consoleLog_(message_ptr: [*]const u8, message_len: c_uint) void;
pub fn consoleLog(message: []const u8) void {
    consoleLog_(message.ptr, message.len);
}

extern fn getLocalStorage_(name_ptr: [*]const u8, name_len: c_int, value_ptr: [*]const u8, value_maxlen: c_int) c_int;
pub fn getLocalStorage(name: []const u8, value: []u8) !usize {
    const n = getLocalStorage_(name.ptr, @intCast(c_int, name.len), value.ptr, @intCast(c_int, value.len));
    if (n < 0) {
        // probably the value was too big to fit in the slice provided
        return error.GetLocalStorageFailed;
    }
    return @intCast(usize, n);
}

extern fn setLocalStorage_(name_ptr: [*]const u8, name_len: c_int, value_ptr: [*]const u8, value_len: c_int) void;
pub fn setLocalStorage(name: []const u8, value: []const u8) void {
    setLocalStorage_(name.ptr, @intCast(c_int, name.len), value.ptr, @intCast(c_int, value.len));
}

extern fn getAssetPtr_(name_ptr: [*]const u8, name_len: c_int) [*]u8;
pub fn getAssetPtr(name: []const u8) [*]u8 {
    return getAssetPtr_(name.ptr, @intCast(c_int, name.len));
}

extern fn getAssetLen_(name_ptr: [*]const u8, name_len: c_int) c_int;
pub fn getAssetLen(name: []const u8) usize {
    return @intCast(usize, getAssetLen_(name.ptr, @intCast(c_int, name.len)));
}

pub fn panic(message: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);
    consoleLog(message);
    while (true) {}
}
