const env = struct {
    // declarations for functions implemented on the javascript side.
    // note: zig supports giving a namespace(?) to extern functions, e.g.
    // `extern "c" fn f() void`. if not specified, it seems to default to
    // "env". this has to match with the JS side.
    extern fn getRandomSeed() c_uint;
    extern fn consoleLog(message_ptr: [*]const u8, message_len: c_uint) void;
    extern fn getAsset(name_ptr: [*]const u8, name_len: c_int, result_addr_ptr: *[*]const u8, result_addr_len_ptr: *c_int) bool;
};

// following are more zig-friendly wrappers around the extern functions.

pub usingnamespace @import("zig-webgl");

pub fn getRandomSeed() c_uint {
    return env.getRandomSeed();
}

pub fn consoleLog(message: []const u8) void {
    env.consoleLog(message.ptr, message.len);
}

// retrieve a game asset (assets are external and are provided from the
// javascript side)
pub fn getAsset(name: []const u8) ?[]const u8 {
    var ptr: [*]const u8 = undefined;
    var len: c_int = undefined;
    if (env.getAsset(name.ptr, @intCast(c_int, name.len), &ptr, &len)) {
        return ptr[0..@intCast(usize, len)];
    } else {
        return null;
    }
}
