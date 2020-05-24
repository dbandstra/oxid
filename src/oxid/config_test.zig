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
            .left => .{ .key = .left },
            .right => .{ .key = .right },
            .up => .{ .key = .up },
            .down => .{ .key = .down },
            .escape => .{ .key = .escape },
            .enter => .{ .key = .@"return" },
            .yes => .{ .key = .y },
            .no => .{ .key = .n },
        };
    }
    inline for (@typeInfo(input.GameCommand).Enum.fields) |field| {
        const value = @intToEnum(input.GameCommand, field.value);
        cfg.game_bindings[0][field.value] = switch (value) {
            .up => .{ .joy_axis_neg = .{ .which = 0, .axis = 1 } },
            .down => .{ .joy_axis_pos = .{ .which = 0, .axis = 1 } },
            .left => .{ .joy_axis_neg = .{ .which = 0, .axis = 0 } },
            .right => .{ .joy_axis_pos = .{ .which = 0, .axis = 0 } },
            .shoot => .{ .joy_button = .{ .which = 0, .button = 1 } },
            .kill_all_monsters => null,
            .toggle_draw_boxes => null,
            .toggle_god_mode => null,
            .escape => .{ .key = .escape },
        };
        cfg.game_bindings[1][field.value] = switch (value) {
            .up => .{ .key = .w },
            .down => .{ .key = .s },
            .left => .{ .key = .a },
            .right => .{ .key = .d },
            .shoot => .{ .key = .f },
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

    var stream = std.io.fixedBufferStream(fixture_json).inStream();
    const cfg = try config.read(
        @TypeOf(stream),
        &stream,
        fixture_json.len,
        &hunk.low(),
    );
    std.testing.expect(std.meta.eql(getFixtureConfig(), cfg));
}

test "config.write" {
    var buffer: [4000]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    var stream = fbs.outStream();
    try config.write(@TypeOf(stream), &stream, getFixtureConfig());
    std.testing.expectEqualSlices(u8, fixture_json, fbs.getWritten());
}
