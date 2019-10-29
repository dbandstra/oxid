const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
const InputSource = @import("../common/key.zig").InputSource;
const JoyAxis = @import("../common/key.zig").JoyAxis;
const JoyButton = @import("../common/key.zig").JoyButton;
const input = @import("input.zig");
const config = @import("config.zig");

fn getFixtureConfig() config.Config {
    var cfg = config.Config {
        .volume = 100,
        .menu_bindings = undefined,
        .game_bindings = undefined,
    };

    for (cfg.menu_bindings) |*binding, i| {
        binding.* = switch (@intToEnum(input.MenuCommand, @intCast(@TagType(input.MenuCommand), i))) {
            .Left => InputSource { .Key = .Left },
            .Right => InputSource { .Key = .Right },
            .Up => InputSource { .Key = .Up },
            .Down => InputSource { .Key = .Down },
            .Escape => InputSource { .Key = .Escape },
            .Enter => InputSource { .Key = .Return },
            .Yes => InputSource { .Key = .Y },
            .No => InputSource { .Key = .N },
        };
    }

    for (cfg.game_bindings) |*binding, i| {
        binding.* = switch (@intToEnum(input.GameCommand, @intCast(@TagType(input.GameCommand), i))) {
            .Up => InputSource { .JoyAxisNeg = JoyAxis { .which = 0, .axis = 1 } },
            .Down => InputSource { .JoyAxisPos = JoyAxis { .which = 0, .axis = 1 } },
            .Left => InputSource { .JoyAxisNeg = JoyAxis { .which = 0, .axis = 0 } },
            .Right => InputSource { .JoyAxisPos = JoyAxis { .which = 0, .axis = 0 } },
            .Shoot => InputSource { .JoyButton = JoyButton { .which = 0, .button = 1 } },
            .KillAllMonsters => null,
            .ToggleDrawBoxes => null,
            .ToggleGodMode => null,
            .Escape => InputSource { .Key = .Escape },
        };
    }

    return cfg;
}

const fixture_json =
\\{
\\    "volume": 100,
\\    "menu_bindings": {
\\        "Left": {"type": "key", "key": "Left"},
\\        "Right": {"type": "key", "key": "Right"},
\\        "Up": {"type": "key", "key": "Up"},
\\        "Down": {"type": "key", "key": "Down"},
\\        "Escape": {"type": "key", "key": "Escape"},
\\        "Enter": {"type": "key", "key": "Return"},
\\        "Yes": {"type": "key", "key": "Y"},
\\        "No": {"type": "key", "key": "N"}
\\    },
\\    "game_bindings": {
\\        "Left": {"type": "joy_axis_neg", "axis": 0},
\\        "Right": {"type": "joy_axis_pos", "axis": 0},
\\        "Up": {"type": "joy_axis_neg", "axis": 1},
\\        "Down": {"type": "joy_axis_pos", "axis": 1},
\\        "Shoot": {"type": "joy_button", "button": 1},
\\        "ToggleGodMode": null,
\\        "ToggleDrawBoxes": null,
\\        "KillAllMonsters": null,
\\        "Escape": {"type": "key", "key": "Escape"}
\\    }
\\}
\\
;

test "config.read" {
    var hunk_buf: [50000]u8 = undefined; // json decoder seems to require a lot of memory...
    var hunk = Hunk.init(hunk_buf[0..]);

    var sis = std.io.SliceInStream.init(fixture_json);
    const cfg = try config.read(std.io.SliceInStream.Error, &sis.stream, fixture_json.len, &hunk.low());
    std.testing.expect(std.meta.eql(getFixtureConfig(), cfg));
}

test "config.write" {
    var buffer: [4000]u8 = undefined;
    var sos = std.io.SliceOutStream.init(buffer[0..]);
    try config.write(std.io.SliceOutStream.Error, &sos.stream, getFixtureConfig());
    std.testing.expectEqualSlices(u8, fixture_json, sos.getWritten());
}
