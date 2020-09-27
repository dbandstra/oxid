const std = @import("std");

pub const Direction = enum {
    n,
    e,
    s,
    w,
};

pub const Vec2 = struct {
    x: i32,
    y: i32,
};

pub const Box = struct {
    mins: Vec2,
    maxs: Vec2,
};

pub fn getNormal(dir: Direction) Vec2 {
    return switch (dir) {
        .n => vec2(0, -1),
        .e => vec2(1, 0),
        .s => vec2(0, 1),
        .w => vec2(-1, 0),
    };
}

pub fn invertDirection(dir: Direction) Direction {
    return switch (dir) {
        .n => .s,
        .e => .w,
        .s => .n,
        .w => .e,
    };
}

pub fn rotateCW(dir: Direction) Direction {
    return switch (dir) {
        .n => .e,
        .e => .s,
        .s => .w,
        .w => .n,
    };
}

pub fn rotateCCW(dir: Direction) Direction {
    return switch (dir) {
        .n => .w,
        .e => .n,
        .s => .e,
        .w => .s,
    };
}

pub fn vec2(x: i32, y: i32) Vec2 {
    return .{
        .x = x,
        .y = y,
    };
}

pub fn vec2Add(a: Vec2, b: Vec2) Vec2 {
    return .{
        .x = a.x + b.x,
        .y = a.y + b.y,
    };
}

pub fn vec2Scale(a: Vec2, f: i32) Vec2 {
    return .{
        .x = a.x * f,
        .y = a.y * f,
    };
}

pub fn vec2Equals(a: Vec2, b: Vec2) bool {
    return a.x == b.x and a.y == b.y;
}

pub fn manhattanDistance(a: Vec2, b: Vec2) u32 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    const adx = if (dx > 0) @intCast(u32, dx) else @intCast(u32, -dx);
    const ady = if (dy > 0) @intCast(u32, dy) else @intCast(u32, -dy);
    return adx + ady;
}

pub fn moveBox(box: Box, vec: Vec2) Box {
    return .{
        .mins = vec2Add(box.mins, vec),
        .maxs = vec2Add(box.maxs, vec),
    };
}

pub fn absBoxesOverlap(a: Box, b: Box) bool {
    std.debug.assert(a.mins.x < a.maxs.x and a.mins.y < a.maxs.y);
    std.debug.assert(b.mins.x < b.maxs.x and b.mins.y < b.maxs.y);

    return a.maxs.x >= b.mins.x and
        b.maxs.x >= a.mins.x and
        a.maxs.y >= b.mins.y and
        b.maxs.y >= a.mins.y;
}

pub fn boxesOverlap(a_pos: Vec2, a_box: Box, b_pos: Vec2, b_box: Box) bool {
    return absBoxesOverlap(moveBox(a_box, a_pos), moveBox(b_box, b_pos));
}

test "boxesOverlap" {
    const box: Box = .{
        .mins = vec2(0, 0),
        .maxs = vec2(15, 15),
    };
    std.testing.expect(!boxesOverlap(vec2(0, 0), box, vec2(16, 0), box));
    std.testing.expect(boxesOverlap(vec2(0, 0), box, vec2(15, 0), box));
    std.testing.expect(!boxesOverlap(vec2(0, 0), box, vec2(-16, 0), box));
    std.testing.expect(boxesOverlap(vec2(0, 0), box, vec2(-15, 0), box));
}
