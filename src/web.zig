const builtin = @import("builtin");

// this file contains declarations for functions implemented on the javascript
// side.
//
// note: zig supports giving a namespace(?) to extern functions, like this:
//
//   extern "hello" funcName() void;
//
// if not specified, it seems to default to "env". this has to match with the
// JS side.

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

extern fn getAsset_(name_ptr: [*]const u8, name_len: c_int, result_address_ptr: *[*]const u8, result_address_len_ptr: *c_int) bool;
pub fn getAsset(name: []const u8) ?[]const u8 {
    var ptr: [*]const u8 = undefined;
    var len: c_int = undefined;
    if (getAsset_(name.ptr, @intCast(c_int, name.len), &ptr, &len)) {
        return ptr[0..@intCast(usize, len)];
    } else {
        return null;
    }
}

pub fn panic(message: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);
    consoleLog(message);
    while (true) {}
}
