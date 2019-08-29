const wasm = @import("web/wasm.zig");
const webgl = @import("web/webgl.zig");

// pub use wasm;
pub use webgl;

const builtin = @import("builtin");
pub const allocator = @import("std").heap.wasm_allocator;
pub const Window = c_void;

pub fn consoleLog(msg: []const u8) void {
    wasm.consoleLogS(msg.ptr, msg.len);
}

pub fn panic(message: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    @setCold(true);
    wasm.consoleLogS(message.ptr, message.len);
    while (true) {}
}

pub fn initShader(source: []const u8, name: []const u8, kind: c_uint) c_uint {
    return webgl.glInitShader(source.ptr, source.len, kind);
}

pub fn linkShaderProgram(vertex_id: c_uint, fragment_id: c_uint, geometry_id: ?c_uint) c_uint {
    return webgl.glLinkShaderProgram(vertex_id, fragment_id);
}
