const std = @import("std");

pub const Direction = enum {
    N,
    E,
    S,
    W,

    pub fn normal(direction: Direction) Vec2 {
        return switch (direction) {
            .N => Vec2.init(0, -1),
            .E => Vec2.init(1, 0),
            .S => Vec2.init(0, 1),
            .W => Vec2.init(-1, 0),
        };
    }

    pub fn invert(direction: Direction) Direction {
        return switch (direction) {
            .N => .S,
            .E => .W,
            .S => .N,
            .W => .E,
        };
    }

    pub fn rotateCw(direction: Direction) Direction {
        return switch (direction) {
            .N => .E,
            .E => .S,
            .S => .W,
            .W => .N,
        };
    }

    pub fn rotateCcw(direction: Direction) Direction {
        return switch (direction) {
            .N => .W,
            .E => .N,
            .S => .E,
            .W => .S,
        };
    }
};

pub const Vec2 = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) Vec2 {
        return .{
            .x = x,
            .y = y,
        };
    }

    pub fn add(a: Vec2, b: Vec2) Vec2 {
        return .{
            .x = a.x + b.x,
            .y = a.y + b.y,
        };
    }

    pub fn scale(a: Vec2, f: i32) Vec2 {
        return .{
            .x = a.x * f,
            .y = a.y * f,
        };
    }

    pub fn equals(a: Vec2, b: Vec2) bool {
        return a.x == b.x and a.y == b.y;
    }

    pub fn manhattanDistance(a: Vec2, b: Vec2) u32 {
        const dx = a.x - b.x;
        const dy = a.y - b.y;
        const adx = if (dx > 0) @intCast(u32, dx) else @intCast(u32, -dx);
        const ady = if (dy > 0) @intCast(u32, dy) else @intCast(u32, -dy);
        return adx + ady;
    }
};

pub const BoundingBox = struct{
    mins: Vec2,
    maxs: Vec2,

    pub fn move(bbox: BoundingBox, vec: Vec2) BoundingBox {
        return .{
            .mins = Vec2.add(bbox.mins, vec),
            .maxs = Vec2.add(bbox.maxs, vec),
        };
    }
};

pub fn absBoxesOverlap(a: BoundingBox, b: BoundingBox) bool {
    std.debug.assert(a.mins.x < a.maxs.x and a.mins.y < a.maxs.y);
    std.debug.assert(b.mins.x < b.maxs.x and b.mins.y < b.maxs.y);

    return
        a.maxs.x >= b.mins.x and
        b.maxs.x >= a.mins.x and
        a.maxs.y >= b.mins.y and
        b.maxs.y >= a.mins.y;
}

pub fn boxesOverlap(
    a_pos: Vec2, a_bbox: BoundingBox,
    b_pos: Vec2, b_bbox: BoundingBox,
) bool {
    return absBoxesOverlap(
        BoundingBox.move(a_bbox, a_pos),
        BoundingBox.move(b_bbox, b_pos),
    );
}

test "boxesOverlap" {
    const bbox: BoundingBox = .{
        .mins = Vec2.init(0, 0),
        .maxs = Vec2.init(15, 15),
    };

    std.testing.expect(!boxesOverlap(
        Vec2.init(0, 0), bbox,
        Vec2.init(16, 0), bbox,
    ));
    std.testing.expect(boxesOverlap(
        Vec2.init(0, 0), bbox,
        Vec2.init(15, 0), bbox,
    ));
    std.testing.expect(!boxesOverlap(
        Vec2.init(0, 0), bbox,
        Vec2.init(-16, 0), bbox,
    ));
    std.testing.expect(boxesOverlap(
        Vec2.init(0, 0), bbox,
        Vec2.init(-15, 0), bbox,
    ));
}
