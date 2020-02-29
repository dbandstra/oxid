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
    inline for (@typeInfo(input.MenuCommand).Enum.fields) |field| {
        const value = @intToEnum(input.MenuCommand, field.value);
        cfg.menu_bindings[field.value] = switch (value) {
            .left => .{ .Key = .left },
            .right => .{ .Key = .right },
            .up => .{ .Key = .up },
            .down => .{ .Key = .down },
            .escape => .{ .Key = .escape },
            .enter => .{ .Key = .@"return" },
            .yes => .{ .Key = .y },
            .no => .{ .Key = .n },
        };
    }
    inline for (@typeInfo(input.GameCommand).Enum.fields) |field| {
        const value = @intToEnum(input.GameCommand, field.value);
        cfg.game_bindings[0][field.value] = switch (value) {
            .up => .{ .JoyAxisNeg = .{ .which = 0, .axis = 1 } },
            .down => .{ .JoyAxisPos = .{ .which = 0, .axis = 1 } },
            .left => .{ .JoyAxisNeg = .{ .which = 0, .axis = 0 } },
            .right => .{ .JoyAxisPos = .{ .which = 0, .axis = 0 } },
            .shoot => .{ .JoyButton = .{ .which = 0, .button = 1 } },
            .kill_all_monsters => null,
            .toggle_draw_boxes => null,
            .toggle_god_mode => null,
            .escape => .{ .Key = .escape },
        };
        cfg.game_bindings[1][field.value] = switch (value) {
            .up => .{ .Key = .w },
            .down => .{ .Key = .s },
            .left => .{ .Key = .a },
            .right => .{ .Key = .d },
            .shoot => .{ .Key = .f },
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
\\        "left": {"type": "key", "key": "left"},
\\        "right": {"type": "key", "key": "right"},
\\        "up": {"type": "key", "key": "up"},
\\        "down": {"type": "key", "key": "down"},
\\        "escape": {"type": "key", "key": "escape"},
\\        "enter": {"type": "key", "key": "return"},
\\        "yes": {"type": "key", "key": "y"},
\\        "no": {"type": "key", "key": "n"}
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
\\        "escape": {"type": "key", "key": "escape"}
\\    },
\\    "game_bindings2": {
\\        "left": {"type": "key", "key": "a"},
\\        "right": {"type": "key", "key": "d"},
\\        "up": {"type": "key", "key": "w"},
\\        "down": {"type": "key", "key": "s"},
\\        "shoot": {"type": "key", "key": "f"},
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
