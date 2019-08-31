const builtin = @import("builtin");
const std = @import("std");
const warn = @import("../warn.zig").warn;

const disabled = builtin.arch == .wasm32;

const num_samples: usize = 60;

pub const Timer =
    if (disabled)
        void
    else
        struct {
            label: []const u8,
            timer: std.time.Timer,
            samples: [num_samples]u64,
            cursor: usize,
            filled: bool,
        };

var spam = false;

fn initTimer(label: []const u8) !Timer {
    if (disabled) {
        // avoid "function with inferred error set must return at least one possible error"
        var i: u1 = 0; if (i == 1) return error.FakeError;
        return Timer {};
    } else {
        return Timer {
            .label = label,
            .timer = try std.time.Timer.start(),
            .samples = [1]u64{0} ** num_samples,
            .cursor = 0,
            .filled = false,
        };
    }
}

pub const Timers = struct {
    Frame: Timer,
    Draw: Timer,
    DrawSort: Timer,
    DrawMap: Timer,
    DrawMapForeground: Timer,
    DrawHud: Timer,
    DrawEntities: Timer,
    WholeDraw: Timer,
};

pub var timers: Timers = undefined;

pub fn init() !void {
    inline for (@typeInfo(Timers).Struct.fields) |field| {
        @field(timers, field.name) = try initTimer(field.name);
    }
}

pub fn toggleSpam() void {
    spam = !spam;

    if (spam) {
        inline for (@typeInfo(Timers).Struct.fields) |field| {
            std.mem.set(u64, @field(timers, field.name).samples[0..], 0);
            @field(timers, field.name).cursor = 0;
            @field(timers, field.name).filled = false;
        }
        warn("Perf spam enabled. Collecting initial {} samples...\n", num_samples);
    } else {
        warn("Perf spam disabled.\n");
    }
}

pub fn begin(self: *Timer) void {
    if (!disabled) {
        if (spam) {
            self.timer.reset();
        }
    }
}

pub fn end(self: *Timer) void {
    if (!disabled) {
        if (spam) {
            const time = self.timer.read();
            self.samples[self.cursor] = time;
            self.cursor = (self.cursor + 1) % num_samples;
            if (self.cursor == 0 and !self.filled) {
                self.filled = true;
            }
            if (self.filled) {
                const avg = getAvg(self);
                const fps = u64(1000000000) / avg;
                warn("{} - avg: {}, fps: {}\n", self.label, avg, fps);
            }
        }
    }
}

fn getAvg(timing_history: *const Timer) u64 {
    var cum: u64 = 0;
    var i: usize = 0;
    while (i < num_samples) : (i += 1) {
        cum += timing_history.samples[i];
    }
    return (cum + num_samples / 2) / num_samples;
}
