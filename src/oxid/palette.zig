const draw = @import("../common/draw.zig");

// named colors for the dawnbringer palette
pub const Color = enum {
    black,
    burgundy,
    navy,
    darkgray,
    brown,
    darkgreen,
    salmon,
    mediumgray,
    skyblue,
    orange,
    lightgray,
    lightgreen,
    cyan,
    lightcyan,
    yellow,
    white,
};

pub fn getColor(palette: [48]u8, color: Color) draw.Color {
    const index: usize = @enumToInt(color);
    return .{
        .r = palette[index * 3 + 0],
        .g = palette[index * 3 + 1],
        .b = palette[index * 3 + 2],
    };
}
