const std = @import("std");
const draw = @import("../common/draw.zig");
const math = @import("../common/math.zig");

// TODO - reorganize?

pub fn lessThanField(comptime T: type, comptime field: []const u8) fn (T, T) bool {
    const Impl = struct {
        fn inner(a: T, b: T) bool {
            return @field(a, field) < @field(b, field);
        }
    };

    return Impl.inner;
}

// decrements the timer. return true if it just hit zero (but not if it was
// already at zero
pub fn decrementTimer(timer: *u32) bool {
    if (timer.* > 0) {
        timer.* -= 1;
        if (timer.* == 0) {
            return true;
        }
    }
    return false;
}

pub fn getDirTransform(direction: math.Direction) draw.Transform {
    return switch (direction) {
        .n => .rotate_ccw,
        .e => .identity,
        .s => .rotate_cw,
        .w => .flip_horz,
    };
}

pub const Choice = struct {
    direction: math.Direction,
    score: u32, // lower is better
};

pub const Choices = struct {
    choices: [4]Choice,
    num_choices: usize,

    pub fn init() Choices {
        return .{
            .choices = undefined,
            .num_choices = 0,
        };
    }

    pub fn add(self: *Choices, direction: math.Direction, score: u32) void {
        self.choices[self.num_choices] = .{
            .direction = direction,
            .score = score,
        };
        self.num_choices += 1;
    }

    pub fn choose(self: *Choices) ?math.Direction {
        if (self.num_choices > 0) {
            // TODO - use random if there is a tie.
            std.sort.sort(
                Choice,
                self.choices[0..self.num_choices],
                lessThanField(Choice, "score"),
            );
            return self.choices[0].direction;
        } else {
            return null;
        }
    }
};
