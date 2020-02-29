const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
const InputSource = @import("../common/key.zig").InputSource;
const JoyAxis = @import("../common/key.zig").JoyAxis;
const JoyButton = @import("../common/key.zig").JoyButton;
const input = @import("input.zig");
const config = @import("config.zig");

fn getFixtureConfig() config.Config {
    var cfg: config.Config = .{
        .volume = 100,
        .menu_bindings = undefined,
        .game_bindings = undefined,
    };

    for (cfg.menu_bindings) |*binding, i| {
        binding.* = switch (@intToEnum(input.MenuCommand, @intCast(@TagType(input.MenuCommand), i))) {
            .left => .{ .Key = .Left },
            .right => .{ .Key = .Right },
            .up => .{ .Key = .Up },
            .down => .{ .Key = .Down },
            .escape => .{ .Key = .Escape },
            .enter => .{ .Key = .Return },
            .yes => .{ .Key = .Y },
            .no => .{ .Key = .N },
        };
    }

    for (cfg.game_bindings[0]) |*binding, i| {
        binding.* = switch (@intToEnum(input.GameCommand, @intCast(@TagType(input.GameCommand), i))) {
            .up => .{ .JoyAxisNeg = .{ .which = 0, .axis = 1 } },
            .down => .{ .JoyAxisPos = .{ .which = 0, .axis = 1 } },
            .left => .{ .JoyAxisNeg = .{ .which = 0, .axis = 0 } },
            .right => .{ .JoyAxisPos = .{ .which = 0, .axis = 0 } },
            .shoot => .{ .JoyButton = .{ .which = 0, .button = 1 } },
            .kill_all_monsters => null,
            .toggle_draw_boxes => null,
            .toggle_god_mode => null,
            .escape => .{ .Key = .Escape },
        };
    }

    for (cfg.game_bindings[1]) |*binding, i| {
        binding.* = switch (@intToEnum(input.GameCommand, @intCast(@TagType(input.GameCommand), i))) {
            .up => .{ .Key = .W },
            .down => .{ .Key = .S },
            .left => .{ .Key = .A },
            .right => .{ .Key = .D },
            .shoot => .{ .Key = .F },
            .kill_all_monsters => null,
            .toggle_draw_boxes => null,
            .toggle_god_mode => null,
            .escape => null,
        };
    }

    return cfg;
}

const fixture_json =
\\{
\\    "volume": 100,
\\    "menu_bindings": {
\\        "left": {"type": "key", "key": "Left"},
\\        "right": {"type": "key", "key": "Right"},
\\        "up": {"type": "key", "key": "Up"},
\\        "down": {"type": "key", "key": "Down"},
\\        "escape": {"type": "key", "key": "Escape"},
\\        "enter": {"type": "key", "key": "Return"},
\\        "yes": {"type": "key", "key": "Y"},
\\        "no": {"type": "key", "key": "N"}
\\    },
\\    "game_bindings": {
\\        "left": {"type": "joy_axis_neg", "axis": 0},
\\        "right": {"type": "joy_axis_pos", "axis": 0},
\\        "up": {"type": "joy_axis_neg", "axis": 1},
\\        "down": {"type": "joy_axis_pos", "axis": 1},
\\        "shoot": {"type": "joy_button", "button": 1},
\\        "toggle_god_mode": null,
\\        "toggle_draw_boxes": null,
\\        "kill_all_monsters": null,
\\        "escape": {"type": "key", "key": "Escape"}
\\    },
\\    "game_bindings2": {
\\        "left": {"type": "key", "key": "A"},
\\        "right": {"type": "key", "key": "D"},
\\        "up": {"type": "key", "key": "W"},
\\        "down": {"type": "key", "key": "S"},
\\        "shoot": {"type": "key", "key": "F"},
\\        "toggle_god_mode": null,
\\        "toggle_draw_boxes": null,
\\        "kill_all_monsters": null,
\\        "escape": null
\\    }
\\}
\\
;

test "config.read" {
    // json decoder seems to require a lot of memory...
    var hunk_buf: [50000]u8 = undefined;
    var hunk = Hunk.init(hunk_buf[0..]);

    var sis = std.io.SliceInStream.init(fixture_json);
    const cfg = try config.read(
        std.io.SliceInStream.Error,
        &sis.stream,
        fixture_json.len,
        &hunk.low(),
    );
    std.testing.expect(std.meta.eql(getFixtureConfig(), cfg));
}

test "config.write" {
    var buffer: [4000]u8 = undefined;
    var sos = std.io.SliceOutStream.init(buffer[0..]);
    try config.write(std.io.SliceOutStream.Error, &sos.stream, getFixtureConfig());
    std.testing.expectEqualSlices(u8, fixture_json, sos.getWritten());
}
