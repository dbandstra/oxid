// extern function implemented in javascript
extern fn getTimestamp() c_int;

pub fn timestamp() u64 {
    const ts = getTimestamp();
    if (ts < 0) return 0;
    return @intCast(u64, ts);
}
