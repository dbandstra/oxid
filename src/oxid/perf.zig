const std = @import("std");

pub const Timer = struct {
    label: []const u8,
    timer: std.time.Timer,
    samples: [60]u64,
    cursor: usize,
};

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

pub fn init() void {
    // https://github.com/ziglang/zig/issues/3046
    var blah = std.time.Timer.start() catch |_| @panic("failed to create timer"); // FIXME
    timers.Frame = Timer {
        .label = "Frame",
        .timer = blah,
        .samples = [1]u64{0} ** 60,
        .cursor = 0,
    };
    blah = std.time.Timer.start() catch |_| @panic("failed to create timer"); // FIXME
    timers.Draw = Timer {
        .label = "Draw",
        .timer = blah,
        .samples = [1]u64{0} ** 60,
        .cursor = 0,
    };
    blah = std.time.Timer.start() catch |_| @panic("failed to create timer"); // FIXME
    timers.DrawSort = Timer {
        .label = "DrawSort",
        .timer = blah,
        .samples = [1]u64{0} ** 60,
        .cursor = 0,
    };
    blah = std.time.Timer.start() catch |_| @panic("failed to create timer"); // FIXME
    timers.DrawMap = Timer {
        .label = "DrawMap",
        .timer = blah,
        .samples = [1]u64{0} ** 60,
        .cursor = 0,
    };
    blah = std.time.Timer.start() catch |_| @panic("failed to create timer"); // FIXME
    timers.DrawMapForeground = Timer {
        .label = "DrawMapForeground",
        .timer = blah,
        .samples = [1]u64{0} ** 60,
        .cursor = 0,
    };
    blah = std.time.Timer.start() catch |_| @panic("failed to create timer"); // FIXME
    timers.DrawEntities = Timer {
        .label = "DrawEntities",
        .timer = blah,
        .samples = [1]u64{0} ** 60,
        .cursor = 0,
    };
    blah = std.time.Timer.start() catch |_| @panic("failed to create timer"); // FIXME
    timers.DrawHud = Timer {
        .label = "DrawHud",
        .timer = blah,
        .samples = [1]u64{0} ** 60,
        .cursor = 0,
    };
    blah = std.time.Timer.start() catch |_| @panic("failed to create timer"); // FIXME
    timers.WholeDraw = Timer {
        .label = "WholeDraw",
        .timer = blah,
        .samples = [1]u64{0} ** 60,
        .cursor = 0,
    };
}

pub fn begin(self: *Timer) void {
    self.timer.reset();
}

pub fn end(self: *Timer, spam: bool) void {
    const time = self.timer.read();
    self.samples[self.cursor] = time;
    self.cursor = (self.cursor + 1) % 60;
    if (spam) {
        const avg = getAvg(self);
        const fps = u64(1000000000) / avg;
        std.debug.warn("{} - avg: {}, fps: {}\n", self.label, avg, fps);
    }
}

fn getAvg(timing_history: *const Timer) u64 {
    var cum: u64 = 0;
    var i: usize = 0;
    while (i < 60) : (i += 1) {
        cum += timing_history.samples[i];
    }
    return (cum + 30) / 60;
}
