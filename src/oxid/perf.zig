const builtin = @import("builtin");

pub const Entry = enum {
    Frame,
    Draw,
    DrawSort,
    DrawMap,
    DrawMapForeground,
    DrawHud,
    DrawEntities,
    WholeDraw
};

pub usingnamespace if (builtin.arch == .wasm32)
    struct {
        pub const Timer = void;
        pub fn init() void {}
        pub fn begin(entry: Entry) void {}
        pub fn end(entry: Entry) void {}
    }
else
    struct {
        const std = @import("std");
        const warn = @import("../warn.zig").warn;

        const num_samples: usize = 60;

        var entries: [@typeInfo(Entry).Enum.fields.len]?Timer = undefined;
        var spam = false;

        pub const Timer = struct {
            label: []const u8,
            timer: std.time.Timer,
            samples: [num_samples]u64,
            cursor: usize,
            filled: bool,
        };

        pub fn init() void {
            inline for (entries) |*entry, i| {
                entry.* = initTimer(@typeInfo(Entry).Enum.fields[i].name);
            }
        }

        fn initTimer(label: []const u8) ?Timer {
            return Timer {
                .label = label,
                .timer = std.time.Timer.start() catch |err| {
                    warn("Failed to initialize \"{}\" perf timer: {}\n", label, err);
                    return null;
                },
                .samples = [1]u64{0} ** num_samples,
                .cursor = 0,
                .filled = false,
            };
        }

        pub fn toggleSpam() void {
            spam = !spam;
            if (!spam) {
                warn("Perf spam disabled.\n");
                return;
            }
            for (entries) |*maybe_entry| {
                if (maybe_entry.*) |*entry| {
                    std.mem.set(u64, entry.samples[0..], 0);
                    entry.cursor = 0;
                    entry.filled = false;
                }
            }
            warn("Perf spam enabled. Collecting initial {} samples...\n", num_samples);
        }

        pub fn begin(entry: Entry) void {
            if (!spam) return;
            const self = &(entries[@enumToInt(entry)] orelse return);
            self.timer.reset();
        }

        pub fn end(entry: Entry) void {
            if (!spam) return;
            var self = &(entries[@enumToInt(entry)] orelse return);
            const time = self.timer.read();
            self.samples[self.cursor] = time;
            self.cursor = (self.cursor + 1) % num_samples;
            if (self.cursor == 0 and !self.filled) {
                self.filled = true;
            }
            if (!self.filled) return;
            var cum: u64 = 0;
            var i: usize = 0;
            while (i < num_samples) : (i += 1) {
                cum += self.samples[i];
            }
            const avg = (cum + num_samples / 2) / num_samples;
            const fps = @as(u64, 1000000000) / avg;
            warn("{} - avg: {}, fps: {}\n", self.label, avg, fps);
        }
    }
;
