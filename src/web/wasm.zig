pub extern fn getRandomSeed() c_uint;
pub extern fn getRandomString() [*]const u8;
pub extern fn consoleLog(_: c_int) void;
pub extern fn consoleLogF(_: f32) void;
pub extern fn consoleLogS(_: [*]const u8, _: c_uint) void;
