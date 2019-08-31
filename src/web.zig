const builtin = @import("builtin");

pub usingnamespace @import("web/webgl.zig");
pub usingnamespace @import("web/webgl_generated.zig");
pub usingnamespace @import("web/keycodes.zig");

pub extern fn getRandomSeed() c_uint;

extern fn consoleLog_(message_ptr: [*]const u8, message_len: c_uint) void;
pub fn consoleLog(message: []const u8) void {
    consoleLog_(message.ptr, message.len);
}

pub fn panic(message: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);
    consoleLog(message);
    while (true) {}
}
