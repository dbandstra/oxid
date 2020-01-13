const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const warn = @import("../warn.zig").warn;
const Key = @import("../common/key.zig").Key;
const InputSource = @import("../common/key.zig").InputSource;
const JoyButton = @import("../common/key.zig").JoyButton;
const JoyAxis = @import("../common/key.zig").JoyAxis;
const input = @import("input.zig");

pub const num_players = 2; // hardcoded for now

pub const Config = struct {
    volume: u32,
    menu_bindings: [@typeInfo(input.MenuCommand).Enum.fields.len]?InputSource,
    game_bindings: [num_players][@typeInfo(input.GameCommand).Enum.fields.len]?InputSource,
};

pub const default = Config {
    .volume = 100,
    .menu_bindings = blk: {
        var bindings: [@typeInfo(input.MenuCommand).Enum.fields.len]?InputSource = undefined;
        for (bindings) |*binding, i| {
            binding.* = switch (@intToEnum(input.MenuCommand, @intCast(@TagType(input.MenuCommand), i))) {
                .Left => .{ .Key = .Left },
                .Right => .{ .Key = .Right },
                .Up => .{ .Key = .Up },
                .Down => .{ .Key = .Down },
                .Escape => .{ .Key = .Escape },
                .Enter => .{ .Key = .Return },
                .Yes => .{ .Key = .Y },
                .No => .{ .Key = .N },
            };
        }
        break :blk bindings;
    },
    .game_bindings = .{
        blk: {
            var bindings: [@typeInfo(input.GameCommand).Enum.fields.len]?InputSource = undefined;
            for (bindings) |*binding, i| {
                binding.* = switch (@intToEnum(input.GameCommand, @intCast(@TagType(input.GameCommand), i))) {
                    .Up => .{ .Key = .Up },
                    .Down => .{ .Key = .Down },
                    .Left => .{ .Key = .Left },
                    .Right => .{ .Key = .Right },
                    .Shoot => .{ .Key = .Space },
                    .KillAllMonsters => .{ .Key = .Backspace },
                    .ToggleDrawBoxes => .{ .Key = .F2 },
                    .ToggleGodMode => .{ .Key = .F3 },
                    .Escape => .{ .Key = .Escape },
                };
            }
            break :blk bindings;
        },
        blk: {
            var bindings: [@typeInfo(input.GameCommand).Enum.fields.len]?InputSource = undefined;
            for (bindings) |*binding, i| {
                binding.* = switch (@intToEnum(input.GameCommand, @intCast(@TagType(input.GameCommand), i))) {
                    .Up => .{ .Key = .W },
                    .Down => .{ .Key = .S },
                    .Left => .{ .Key = .A },
                    .Right => .{ .Key = .D },
                    .Shoot => .{ .Key = .F },
                    .KillAllMonsters => null,
                    .ToggleDrawBoxes => null,
                    .ToggleGodMode => null,
                    .Escape => null,
                };
            }
            break :blk bindings;
        },
    },
};

///////////////////////////////////////////////////////////

// reading config json

pub fn read(comptime ReadError: type, stream: *std.io.InStream(ReadError), size: usize, hunk_side: *HunkSide) !Config {
    const mark = hunk_side.getMark();
    defer hunk_side.freeToMark(mark);

    var contents = try hunk_side.allocator.alloc(u8, size);
    try stream.readNoEof(contents);

    var p = std.json.Parser.init(&hunk_side.allocator, false);
    defer p.deinit();

    var tree = try p.parse(contents);
    defer tree.deinit();

    var cfg = default;

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
                            warn("Value of \"volume\" must be an integer\n", .{});
                        },
                    }
                } else if (std.mem.eql(u8, kv.key, "menu_bindings")) {
                    readBindings(input.MenuCommand, &cfg.menu_bindings, kv.value);
                } else if (std.mem.eql(u8, kv.key, "game_bindings")) {
                    readBindings(input.GameCommand, &cfg.game_bindings[0], kv.value);
                } else if (std.mem.eql(u8, kv.key, "game_bindings2")) {
                    readBindings(input.GameCommand, &cfg.game_bindings[1], kv.value);
                } else {
                    warn("Unrecognized config field: '{}'\n", .{kv.key});
                }
            }
        },
        else => {
            warn("Top-level value must be an object\n", .{});
        },
    }

    return cfg;
}

// this function seems to work even if the `bindings` argument is not a
// pointer. i guess arrays are not copied. but is that something i can rely on
// always being true, or is it some kind of "undefined" behaviour (e.g. maybe
// arrays are only copied if below some length known only to the compiler
// implementation)? seems safer to use a pointer.
fn readBindings(comptime CommandType: type, bindings: *[@typeInfo(CommandType).Enum.fields.len]?InputSource, value: std.json.Value) void {
    switch (value) {
        .Object => |map| {
            var it = map.iterator();
            while (it.next()) |kv| {
                const command = parseCommand(CommandType, kv.key) orelse continue;
                const source = parseInputSource(kv.value) catch {
                    warn("Error parsing input source for command '{}'\n", .{kv.key});
                    continue;
                };
                bindings.*[@enumToInt(command)] = source;
            }
        },
        else => {
            warn("Value of \"menu_bindings\" must be an object\n", .{});
        },
    }
}

fn parseCommand(comptime CommandType: type, s: []const u8) ?CommandType {
    inline for (@typeInfo(CommandType).Enum.fields) |field| {
        if (std.mem.eql(u8, s, field.name)) {
            return @intToEnum(CommandType, field.value);
        }
    } else {
        warn("Unrecognized {}: '{}'\n", .{@typeName(CommandType), s});
        return null;
    }
}

fn parseInputSource(value: std.json.Value) !?InputSource {
    switch (value) {
        .Object => |map| {
            const source_type_value = map.getValue("type") orelse return error.Failed;
            const source_type = switch (source_type_value) {
                .String => |s| s,
                else => return error.Failed,
            };
            if (std.mem.eql(u8, source_type, "key")) {
                const key_name_value = map.getValue("key") orelse return error.Failed;
                const key_name = switch (key_name_value) {
                    .String => |s| s,
                    else => return error.Failed,
                };
                inline for (@typeInfo(Key).Enum.fields) |field| {
                    if (std.mem.eql(u8, key_name, field.name)) {
                        return InputSource { .Key = @intToEnum(Key, field.value) };
                    }
                } else {
                    return error.Failed;
                }
            } else if (std.mem.eql(u8, source_type, "joy_button")) {
                const button_value = map.getValue("button") orelse return error.Failed;
                const button = switch (button_value) {
                    .Integer => |n| std.math.cast(u32, n) catch return error.Failed,
                    else => return error.Failed,
                };
                // FIXME - doesn't feel right to reset `which` to 0, but it also doesn't feel right to save which joystick in the config file?
                return InputSource { .JoyButton = JoyButton { .which = 0, .button = button } };
            } else if (std.mem.eql(u8, source_type, "joy_axis_neg") or std.mem.eql(u8, source_type, "joy_axis_pos")) {
                const axis_value = map.getValue("axis") orelse return error.Failed;
                const axis = switch (axis_value) {
                    .Integer => |n| std.math.cast(u32, n) catch return error.Failed,
                    else => return error.Failed,
                };
                // FIXME - doesn't feel right to reset `which` to 0, but it also doesn't feel right to save which joystick in the config file?
                if (std.mem.eql(u8, source_type, "joy_axis_neg")) {
                    return InputSource { .JoyAxisNeg = JoyAxis { .which = 0, .axis = axis } };
                } else {
                    return InputSource { .JoyAxisPos = JoyAxis { .which = 0, .axis = axis } };
                }
            } else {
                return error.Failed;
            }
        },
        .Null => {
            return null;
        },
        else => {
            return error.Failed;
        }
    }
}

///////////////////////////////////////////////////////////

// writing config json

fn getEnumValueName(comptime T: type, value: T) []const u8 {
    inline for (@typeInfo(T).Enum.fields) |field| {
        if (@intToEnum(T, field.value) == value) {
            return field.name;
        }
    }
    unreachable;
}

pub fn write(comptime WriteError: type, stream: *std.io.OutStream(WriteError), cfg: Config) !void {
    try stream.print(
        \\{{
        \\    "volume": {},
        \\    "menu_bindings": {{
        \\
    , .{cfg.volume});
    try writeBindings(WriteError, stream, input.MenuCommand, cfg.menu_bindings);
    try stream.print(
        \\    }},
        \\    "game_bindings": {{
        \\
    , .{});
    try writeBindings(WriteError, stream, input.GameCommand, cfg.game_bindings[0]);
    try stream.print(
        \\    }},
        \\    "game_bindings2": {{
        \\
    , .{});
    try writeBindings(WriteError, stream, input.GameCommand, cfg.game_bindings[1]);
    try stream.print(
        \\    }}
        \\}}
        \\
    , .{});
}

fn writeBindings(comptime WriteError: type, stream: *std.io.OutStream(WriteError), comptime CommandType: type, bindings: [@typeInfo(CommandType).Enum.fields.len]?InputSource) !void {
    // don't bother with backslash escaping strings because we know none of
    // the possible values have characters that would need escaping
    for (bindings) |maybe_source, i| {
        const command = @intToEnum(CommandType, @intCast(@TagType(CommandType), i));
        const command_name = getEnumValueName(CommandType, command);
        try stream.print("        \"{}\": ", .{command_name});
        if (maybe_source) |source| {
            switch (source) {
                .Key => |key| {
                    try stream.print("{{\"type\": \"key\", \"key\": \"{}\"}}", .{getEnumValueName(Key, key)});
                },
                .JoyButton => |j| {
                    try stream.print("{{\"type\": \"joy_button\", \"button\": {}}}", .{j.button});
                },
                .JoyAxisNeg => |j| {
                    try stream.print("{{\"type\": \"joy_axis_neg\", \"axis\": {}}}", .{j.axis});
                },
                .JoyAxisPos => |j| {
                    try stream.print("{{\"type\": \"joy_axis_pos\", \"axis\": {}}}", .{j.axis});
                },
            }
        } else {
            try stream.print("null", .{});
        }
        if (i < bindings.len - 1) {
            try stream.print(",", .{});
        }
        try stream.print("\n", .{});
    }
}
