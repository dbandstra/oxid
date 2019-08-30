const builtin = @import("builtin");

const wasm = @import("web/wasm.zig");
pub usingnamespace @import("web/webgl.zig");
pub usingnamespace @import("web/webgl_generated.zig");
pub usingnamespace @import("web/keycodes.zig");

pub fn consoleLog(message: []const u8) void {
    wasm.consoleLog(message.ptr, message.len);
}

pub fn panic(message: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);
    wasm.consoleLog(message.ptr, message.len);
    while (true) {}
}
