const std = @import("std");

pub fn timestamp() u64 {
    const ts = std.time.timestamp();
    if (ts < 0) return 0;
    return @intCast(u64, ts);
}
