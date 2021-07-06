const std = @import("std");
const builtin = @import("builtin");

pub const Entry = enum {
    frame,
    draw,
    draw_sort,
    draw_map,
    draw_map_foreground,
    draw_hud,
    draw_entities,
    whole_draw,
};

pub usingnamespace if (std.Target.current.isWasm() or builtin.mode == .ReleaseSmall)
    struct {
        pub const Timer = void;
        pub fn init() void {}
        pub fn toggleSpam() void {}
        pub fn begin(entry: Entry) void {}
        pub fn end(entry: Entry) void {}
    }
else
    struct {
        const std = @import("std");

        const num_samples: usize = 60;
        var global_cursor: usize = 0;

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
            return Timer{
                .label = label,
                .timer = std.time.Timer.start() catch |err| {
                    std.log.err("Failed to initialize \"{s}\" perf timer: {}", .{ label, err });
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
                std.log.notice("Perf spam disabled.", .{});
                return;
            }
            for (entries) |*maybe_entry| {
                if (maybe_entry.*) |*entry| {
                    std.mem.set(u64, entry.samples[0..], 0);
                    entry.cursor = 0;
                    entry.filled = false;
                }
            }
            std.log.notice("Perf spam enabled. Collecting initial {} samples...", .{num_samples});
        }

        pub fn begin(entry: Entry) void {
            if (!spam) return;
            const self = &(entries[@enumToInt(entry)] orelse return);
            self.timer.reset();
        }

        pub fn end(entry: Entry) void {
            if (!spam) return;
            const self = &(entries[@enumToInt(entry)] orelse return);
            const time = self.timer.read();
            self.samples[self.cursor] = time;
            self.cursor = (self.cursor + 1) % num_samples;
            if (self.cursor == 0 and !self.filled) {
                self.filled = true;
            }
            // FIXME - self.samples will retain stale content if begin/end are
            // not called in a frame
        }

        pub fn display() void {
            if (!spam) return;
            global_cursor = (global_cursor + 1) % num_samples;
            if (global_cursor != 0) return;
            std.log.notice(".", .{});
            displayOne("`-Frame ......... ", .frame);
            displayOne("`-WholeDraw ..... ", .whole_draw);
            displayOne("  `-Draw ........ ", .draw);
            displayOne("    `-DrawSort .. ", .draw_sort);
            displayOne("    `-DrawMap ... ", .draw_map);
            displayOne("    `-DrawEnts .. ", .draw_entities);
            displayOne("    `-DrawMapFg . ", .draw_map_foreground);
            displayOne("    `-DrawHud ... ", .draw_hud);
        }

        fn displayOne(label: []const u8, entry: Entry) void {
            const self = &(entries[@enumToInt(entry)] orelse {
                std.log.notice("{s} - timer error", .{label});
                return;
            });
            if (!self.filled) {
                std.log.notice("{s} - waiting", .{label});
                return;
            }
            var cum: u64 = 0;
            var i: usize = 0;
            while (i < num_samples) : (i += 1) {
                cum += self.samples[i];
            }
            const avg = (cum + num_samples / 2) / num_samples;
            const fps = @as(u64, 1000000000) / avg;
            const avg_us = @intToFloat(f32, avg) / 1000.0;
            // std.fmt api doesn't support alignment
            if (avg_us < 10.0) {
                std.log.notice("{s} -    {d:.3} μs ({} fps)", .{ label, avg_us, fps });
            } else if (avg_us < 100.0) {
                std.log.notice("{s} -   {d:.3} μs ({} fps)", .{ label, avg_us, fps });
            } else if (avg_us < 1000.0) {
                std.log.notice("{s} -  {d:.3} μs ({} fps)", .{ label, avg_us, fps });
            } else {
                std.log.notice("{s} - {d:.3} μs ({} fps)", .{ label, avg_us, fps });
            }
        }
    };
