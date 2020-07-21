const std = @import("std");
const draw = @import("../common/draw.zig");
const math = @import("../common/math.zig");

// TODO - reorganize?

pub fn lessThanField(comptime T: type, comptime field: []const u8) fn (void, T, T) bool {
    const Impl = struct {
        fn inner(context: void, a: T, b: T) bool {
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

pub const DirectionChoices = struct {
    scores: [@typeInfo(math.Direction).Enum.fields.len]?u32,

    pub fn init() DirectionChoices {
        return .{
            .scores = [1]?u32{null} ** @typeInfo(math.Direction).Enum.fields.len,
        };
    }

    pub fn add(self: *DirectionChoices, direction: math.Direction, score: u32) void {
        const i = @enumToInt(direction);
        if (self.scores[i]) |current_score| {
            if (current_score < score) {
                return;
            }
        }
        self.scores[i] = score;
    }

    // return the direction with the lowest score
    pub fn chooseLowest(self: *const DirectionChoices) ?math.Direction {
        var best_dir: ?math.Direction = null;
        var best_score: u32 = undefined;
        for (self.scores) |maybe_score, i| {
            const score = maybe_score orelse continue;
            if (best_dir == null or score < best_score) {
                best_dir = @intToEnum(math.Direction, @intCast(@TagType(math.Direction), i));
                best_score = score;
            }
        }
        return best_dir;
    }

    // return a random direction, weighted by score (higher score is more likely to be picked)
    pub fn chooseRandom(self: *const DirectionChoices, rng: *std.rand.Random) ?math.Direction {
        const total_score = blk: {
            var total: u32 = 0;
            for (self.scores) |maybe_score| {
                total += maybe_score orelse 0;
            }
            break :blk total;
        };
        if (total_score > 0) {
            var r = rng.intRangeLessThan(u32, 0, total_score);
            for (self.scores) |maybe_score, i| {
                const score = maybe_score orelse continue;
                if (r < score) {
                    return @intToEnum(math.Direction, @intCast(@TagType(math.Direction), i));
                } else {
                    r -= score;
                }
            }
        }
        return null;
    }
};
