const env = struct {
    // declarations for functions implemented on the javascript side.
    // note: zig supports giving a namespace(?) to extern functions, e.g.
    // `extern "c" fn f() void`. if not specified, it seems to default to
    // "env". this has to match with the JS side.
    extern fn getRandomSeed() c_uint;
    extern fn consoleLog(message_ptr: [*]const u8, message_len: c_uint) void;
};

// following are more zig-friendly wrappers around the extern functions.

pub usingnamespace @import("zig-webgl");

pub fn getRandomSeed() c_uint {
    return env.getRandomSeed();
}

pub fn consoleLog(message: []const u8) void {
    env.consoleLog(message.ptr, message.len);
}
