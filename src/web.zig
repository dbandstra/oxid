const env = struct {
    // declarations for functions implemented on the javascript side.
    // note: zig supports giving a namespace(?) to extern functions, e.g.
    // `extern "c" fn f() void`. if not specified, it seems to default to
    // "env". this has to match with the JS side.
    extern fn getRandomSeed() c_uint;
};

// following are more zig-friendly wrappers around the extern functions.

pub usingnamespace @import("zig-webgl");

pub fn getRandomSeed() c_uint {
    return env.getRandomSeed();
}
