// extern function implemented in javascript
extern fn externGetDateTime(out_ptr: [*]u8, out_maxlen: c_int) c_int;

pub fn getDateTime(writer: anytype) !void {
    var buffer: [40]u8 = undefined;

    const bytes_read = externGetDateTime(&buffer, 40);

    if (bytes_read < 0 or bytes_read > 40)
        return error.GetDateTimeFailed;

    try writer.writeAll(buffer[0..@intCast(usize, bytes_read)]);
}
