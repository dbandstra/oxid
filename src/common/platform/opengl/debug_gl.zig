const c = @import("../c.zig");
const builtin = @import("builtin");

pub fn assertNoError() void {
    if (builtin.mode != builtin.Mode.ReleaseFast) {
        const err = c.glGetError();
        if (err != c.GL_NO_ERROR) {
            _ = c.printf(c"GL error: %d\n", err);
            unreachable;
        }
    }
}
