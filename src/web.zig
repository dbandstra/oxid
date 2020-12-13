const env = @import("web/env.zig");

pub usingnamespace @import("web/webgl.zig");
pub usingnamespace @import("web/webgl_generated.zig");

// these functions are more zig-friendly wrappers around the "env" functions
// that are implemented on the javascript side

pub fn getRandomSeed() c_uint {
    return env.getRandomSeed();
}

pub fn consoleLog(message: []const u8) void {
    env.consoleLog(message.ptr, message.len);
}

// read some data from persistent storage
pub fn getLocalStorage(name: []const u8, value: []u8) !usize {
    const n = env.getLocalStorage(name.ptr, @intCast(c_int, name.len), value.ptr, @intCast(c_int, value.len));
    if (n < 0) {
        // probably the value was too big to fit in the slice provided
        return error.GetLocalStorageFailed;
    }
    return @intCast(usize, n);
}

// write some data into persistent storage
pub fn setLocalStorage(name: []const u8, value: []const u8) void {
    env.setLocalStorage(name.ptr, @intCast(c_int, name.len), value.ptr, @intCast(c_int, value.len));
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
