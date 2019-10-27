const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const warn = @import("../warn.zig").warn;
const Key = @import("../common/key.zig").Key;
const InputSource = @import("../common/key.zig").InputSource;
const JoyButton = @import("../common/key.zig").JoyButton;
const JoyAxis = @import("../common/key.zig").JoyAxis;
const input = @import("input.zig");

pub const Config = struct {
    volume: u32,
    menu_bindings: [@typeInfo(input.MenuCommand).Enum.fields.len]?InputSource,
    game_bindings: [@typeInfo(input.GameCommand).Enum.fields.len]?InputSource,
};

// this used to be a simple global constant but there's a compiler bug there.
// (things went haywire when i created the InputSource struct. when it was just
// keys it worked fine. it's probably this issue:
// https://github.com/ziglang/zig/issues/3532 )
pub fn getDefault() Config {
    var default = Config {
        .volume = 100,
        .menu_bindings = undefined,
        .game_bindings = undefined,
    };

    for (default.menu_bindings) |*binding, i| {
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

    for (default.game_bindings) |*binding, i| {
        binding.* = switch (@intToEnum(input.GameCommand, @intCast(@TagType(input.GameCommand), i))) {
            .Up => InputSource { .Key = .Up },
            .Down => InputSource { .Key = .Down },
            .Left => InputSource { .Key = .Left },
            .Right => InputSource { .Key = .Right },
            .Shoot => InputSource { .Key = .Space },
            .KillAllMonsters => InputSource { .Key = .Backspace },
            .ToggleDrawBoxes => InputSource { .Key = .F2 },
            .ToggleGodMode => InputSource { .Key = .F3 },
            .Escape => InputSource { .Key = .Escape },
        };
    }

    return default;
}

pub fn read(comptime ReadError: type, stream: *std.io.InStream(ReadError), size: usize, hunk_side: *HunkSide) !Config {
    const mark = hunk_side.getMark();
    defer hunk_side.freeToMark(mark);

    var contents = try hunk_side.allocator.alloc(u8, size);
    try stream.readNoEof(contents);

    var p = std.json.Parser.init(&hunk_side.allocator, false);
    defer p.deinit();

    var tree = try p.parse(contents);
    defer tree.deinit();

    var cfg = getDefault();

    switch (tree.root) {
        .Object => |map| {
            var it = map.iterator();
            while (it.next()) |kv| {
                if (std.mem.eql(u8, kv.key, "volume")) {
                    switch (kv.value) {
                        .Integer => |v| {
                            cfg.volume = @intCast(u32, std.math.min(100, std.math.max(0, v)));
                        },
                        else => {
                            warn("Value of \"volume\" must be an integer\n");
                        },
                    }
                } else if (std.mem.eql(u8, kv.key, "menu_bindings")) {
                    readMenuBindings(&cfg, kv.value);
                } else if (std.mem.eql(u8, kv.key, "game_bindings")) {
                    readGameBindings(&cfg, kv.value);
                } else {
                    warn("Unrecognized config field: '{}'\n", kv.key);
                }
            }
        },
        else => {
            warn("Top-level value must be an object\n");
        },
    }

    return cfg;
}

fn readMenuBindings(cfg: *Config, value: std.json.Value) void {
    switch (value) {
        .Object => |map| {
            var it = map.iterator();
            while (it.next()) |kv| {
                const command = parseMenuCommand(kv.key) orelse continue;
                cfg.menu_bindings[@enumToInt(command)] = parseInputSource(kv.value);
            }
        },
        else => {
            warn("Value of \"menu_bindings\" must be an object\n");
        },
    }
}

fn readGameBindings(cfg: *Config, value: std.json.Value) void {
    switch (value) {
        .Object => |map| {
            var it = map.iterator();
            while (it.next()) |kv| {
                const command = parseGameCommand(kv.key) orelse continue;
                cfg.game_bindings[@enumToInt(command)] = parseInputSource(kv.value);
            }
        },
        else => {
            warn("Value of \"game_bindings\" must be an object\n");
        },
    }
}

fn parseMenuCommand(s: []const u8) ?input.MenuCommand {
    inline for (@typeInfo(input.MenuCommand).Enum.fields) |field| {
        if (std.mem.eql(u8, s, field.name)) {
            return @intToEnum(input.MenuCommand, field.value);
        }
    } else {
        warn("Unrecognized menu command: '{}'\n", s);
        return null;
    }
}

fn parseGameCommand(s: []const u8) ?input.GameCommand {
    inline for (@typeInfo(input.GameCommand).Enum.fields) |field| {
        if (std.mem.eql(u8, s, field.name)) {
            return @intToEnum(input.GameCommand, field.value);
        }
    } else {
        warn("Unrecognized game command: '{}'\n", s);
        return null;
    }
}

fn parseInputSource(value: std.json.Value) ?InputSource {
    switch (value) {
        .Object => |map| {
            const source_type_value = map.getValue("type") orelse {
                warn("Input binding value must have \"type\" field\n");
                return null;
            };
            const source_type = switch (source_type_value) {
                .String => |s| s,
                else => {
                    warn("Input binding \"type\" must be a string\n");
                    return null;
                },
            };
            if (std.mem.eql(u8, source_type, "key")) {
                const key_name_value = map.getValue("key") orelse {
                    warn("Input binding value with type \"key\" is missing field \"key\"\n");
                    return null;
                };
                const key_name = switch (key_name_value) {
                    .String => |s| s,
                    else => {
                        warn("Input binding \"key\" must be a string\n");
                        return null;
                    },
                };
                inline for (@typeInfo(Key).Enum.fields) |field| {
                    if (std.mem.eql(u8, key_name, field.name)) {
                        return InputSource { .Key = @intToEnum(Key, field.value) };
                    }
                } else {
                    warn("Unrecognized key name: \"{}\"\n", key_name);
                    return null;
                }
            } else if (std.mem.eql(u8, source_type, "joy_button")) {
                const button_value = map.getValue("button") orelse {
                    warn("Input binding value with type \"joy_button\" is missing field \"button\"\n");
                    return null;
                };
                const button = switch (button_value) {
                    .Integer => |n| std.math.cast(u32, n) catch {
                        warn("Input binding \"button\" value is out of range\n");
                        return null;
                    },
                    else => {
                        warn("Input binding \"button\" must be a number\n");
                        return null;
                    },
                };
                // FIXME - doesn't feel right to reset `which` to 0, but it also doesn't feel right to save which joystick in the config file?
                return InputSource { .JoyButton = JoyButton { .which = 0, .button = button } };
            } else if (std.mem.eql(u8, source_type, "joy_axis_neg") or std.mem.eql(u8, source_type, "joy_axis_pos")) {
                const axis_value = map.getValue("axis") orelse {
                    warn("Input binding value with type \"{}\" is missing field \"axis\"\n", source_type);
                    return null;
                };
                const axis = switch (axis_value) {
                    .Integer => |n| std.math.cast(u32, n) catch {
                        warn("Input binding \"axis\" value is out of range\n");
                        return null;
                    },
                    else => {
                        warn("Input binding \"axis\" must be a number\n");
                        return null;
                    },
                };
                // FIXME - doesn't feel right to reset `which` to 0, but it also doesn't feel right to save which joystick in the config file?
                if (std.mem.eql(u8, source_type, "joy_axis_neg")) {
                    return InputSource { .JoyAxisNeg = JoyAxis { .which = 0, .axis = axis } };
                } else {
                    return InputSource { .JoyAxisPos = JoyAxis { .which = 0, .axis = axis } };
                }
            } else {
                warn("Input binding type must be one of: \"key\", \"joy_button\", \"joy_axis_pos\", \"joy_axis_neg\"\n");
                return null;
            }
        },
        .Null => {
            return null;
        },
        else => {
            warn("Input binding value must be an object or null\n");
            return null;
        }
    }
}

fn getEnumValueName(comptime T: type, value: T) []const u8 {
    inline for (@typeInfo(T).Enum.fields) |field| {
        if (@intToEnum(T, field.value) == value) {
            return field.name;
        }
    }
    unreachable;
}

pub fn write(comptime WriteError: type, stream: *std.io.OutStream(WriteError), cfg: Config, hunk_side: *HunkSide) !void {
    try stream.print(
        \\{{
        \\    "volume": {},
        \\    "menu_bindings": {{
        \\
    , cfg.volume);
    // don't bother with backslash escaping strings because we know none of
    // the possible values need it
    for (cfg.menu_bindings) |maybe_source, i| {
        const command = @intToEnum(input.MenuCommand, @intCast(@TagType(input.MenuCommand), i));
        const command_name = getEnumValueName(input.MenuCommand, command);
        try stream.print("        \"{}\": ", command_name);
        if (maybe_source) |source| {
            try writeInputSource(WriteError, stream, source);
        } else {
            try stream.print("null");
        }
        if (i < cfg.menu_bindings.len - 1) {
            try stream.print(",");
        }
        try stream.print("\n");
    }
    try stream.print(
        \\    }},
        \\    "game_bindings": {{
        \\
    );
    for (cfg.game_bindings) |maybe_source, i| {
        const command = @intToEnum(input.GameCommand, @intCast(@TagType(input.GameCommand), i));
        const command_name = getEnumValueName(input.GameCommand, command);
        try stream.print("        \"{}\": ", command_name);
        if (maybe_source) |source| {
            try writeInputSource(WriteError, stream, source);
        } else {
            try stream.print("null");
        }
        if (i < cfg.game_bindings.len - 1) {
            try stream.print(",");
        }
        try stream.print("\n");
    }
    try stream.print(
        \\    }}
        \\}}
        \\
    );
}

fn writeInputSource(comptime WriteError: type, stream: *std.io.OutStream(WriteError), source: InputSource) !void {
    switch (source) {
        .Key => |key| {
            try stream.print("{{\"type\": \"key\", \"key\": \"{}\"}}", getEnumValueName(Key, key));
        },
        .JoyButton => |j| {
            try stream.print("{{\"type\": \"joy_button\", \"button\": {}}}", j.button);
        },
        .JoyAxisNeg => |j| {
            try stream.print("{{\"type\": \"joy_axis_neg\", \"axis\": {}}}", j.axis);
        },
        .JoyAxisPos => |j| {
            try stream.print("{{\"type\": \"joy_axis_pos\", \"axis\": {}}}", j.axis);
        },
    }
}
