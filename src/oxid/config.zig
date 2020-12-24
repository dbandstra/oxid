const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const pstorage = @import("pstorage");
const warn = @import("../warn.zig").warn;
const Key = @import("../common/key.zig").Key;
const InputSource = @import("../common/key.zig").InputSource;
const input = @import("input.zig");

pub const num_players = 2; // hardcoded for now

pub const Config = struct {
    volume: u32,
    menu_bindings: [@typeInfo(input.MenuCommand).Enum.fields.len]?InputSource,
    game_bindings: [num_players][@typeInfo(input.GameCommand).Enum.fields.len]?InputSource,
};

// this can't be a global constant because of a compiler bug
pub fn getDefault() Config {
    var cfg: Config = .{
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
            .up => .{ .key = .up },
            .down => .{ .key = .down },
            .left => .{ .key = .left },
            .right => .{ .key = .right },
            .shoot => .{ .key = .space },
            .kill_all_monsters => .{ .key = .backspace },
            .toggle_draw_boxes => .{ .key = .f2 },
            .toggle_god_mode => .{ .key = .f3 },
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

///////////////////////////////////////////////////////////

// reading config json

pub fn read(hunk_side: *HunkSide, key: []const u8) !Config {
    var maybe_object = try pstorage.ReadableObject.open(hunk_side, key);
    var object = maybe_object orelse return getDefault();
    defer object.close();
    return try readFromStream(object.reader(), object.size, hunk_side);
}

pub fn readFromStream(r: anytype, size: usize, hunk_side: *HunkSide) !Config {
    const mark = hunk_side.getMark();
    defer hunk_side.freeToMark(mark);

    var contents = try hunk_side.allocator.alloc(u8, size);
    try r.readNoEof(contents);

    var p = std.json.Parser.init(&hunk_side.allocator, false);
    defer p.deinit();

    var tree = try p.parse(contents);
    defer tree.deinit();

    // start with the default config. any property that isn't set in the
    // config file will remain with its default value
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
fn readBindings(
    comptime CommandType: type,
    bindings: *[@typeInfo(CommandType).Enum.fields.len]?InputSource,
    value: std.json.Value,
) void {
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
    }
    warn("Unrecognized {}: '{}'\n", .{ @typeName(CommandType), s });
    return null;
}

fn parseInputSource(value: std.json.Value) !?InputSource {
    switch (value) {
        .Object => |map| {
            const source_type_value = map.get("type") orelse return error.Failed;
            const source_type = switch (source_type_value) {
                .String => |s| s,
                else => return error.Failed,
            };
            if (std.mem.eql(u8, source_type, "key")) {
                const key_name_value = map.get("key") orelse return error.Failed;
                const key_name = switch (key_name_value) {
                    .String => |s| s,
                    else => return error.Failed,
                };
                inline for (@typeInfo(Key).Enum.fields) |field| {
                    if (std.mem.eql(u8, key_name, field.name)) {
                        return InputSource{ .key = @intToEnum(Key, field.value) };
                    }
                } else {
                    return error.Failed;
                }
            } else if (std.mem.eql(u8, source_type, "joy_button")) {
                const button_value = map.get("button") orelse return error.Failed;
                const button = switch (button_value) {
                    .Integer => |n| std.math.cast(u32, n) catch return error.Failed,
                    else => return error.Failed,
                };
                // FIXME - doesn't feel right to reset `which` to 0, but it
                // also doesn't feel right to save which joystick in the
                // config file?
                return InputSource{
                    .joy_button = .{ .which = 0, .button = button },
                };
            } else if (std.mem.eql(u8, source_type, "joy_axis_neg") or
                std.mem.eql(u8, source_type, "joy_axis_pos"))
            {
                const axis_value = map.get("axis") orelse return error.Failed;
                const axis = switch (axis_value) {
                    .Integer => |n| std.math.cast(u32, n) catch return error.Failed,
                    else => return error.Failed,
                };
                // FIXME - doesn't feel right to reset `which` to 0, but it
                // also doesn't feel right to save which joystick in the
                // config file?
                if (std.mem.eql(u8, source_type, "joy_axis_neg")) {
                    return InputSource{
                        .joy_axis_neg = .{ .which = 0, .axis = axis },
                    };
                } else {
                    return InputSource{
                        .joy_axis_pos = .{ .which = 0, .axis = axis },
                    };
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
        },
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

pub fn write(hunk_side: *HunkSide, key: []const u8, cfg: Config) !void {
    const object = try pstorage.WritableObject.open(hunk_side, key);
    defer object.close();
    try writeToStream(object.writer(), cfg);
}

pub fn writeToStream(w: anytype, cfg: Config) !void {
    try w.print(
        \\{{
        \\    "volume": {},
        \\    "menu_bindings": {{
        \\
    , .{cfg.volume});
    try writeBindings(w, input.MenuCommand, cfg.menu_bindings);
    try w.print(
        \\    }},
        \\    "game_bindings": {{
        \\
    , .{});
    try writeBindings(w, input.GameCommand, cfg.game_bindings[0]);
    try w.print(
        \\    }},
        \\    "game_bindings2": {{
        \\
    , .{});
    try writeBindings(w, input.GameCommand, cfg.game_bindings[1]);
    try w.print(
        \\    }}
        \\}}
        \\
    , .{});
}

fn writeBindings(
    w: anytype,
    comptime CommandType: type,
    bindings: [@typeInfo(CommandType).Enum.fields.len]?InputSource,
) !void {
    // don't bother with backslash escaping strings because we know none of
    // the possible values have characters that would need escaping
    for (bindings) |maybe_source, i| {
        const command = @intToEnum(CommandType, @intCast(@TagType(CommandType), i));
        const command_name = getEnumValueName(CommandType, command);
        try w.print("        \"{}\": ", .{command_name});
        if (maybe_source) |source| {
            switch (source) {
                .key => |key| {
                    try w.print("{{\"type\": \"key\", \"key\": \"{}\"}}", .{getEnumValueName(Key, key)});
                },
                .joy_button => |j| {
                    try w.print("{{\"type\": \"joy_button\", \"button\": {}}}", .{j.button});
                },
                .joy_axis_neg => |j| {
                    try w.print("{{\"type\": \"joy_axis_neg\", \"axis\": {}}}", .{j.axis});
                },
                .joy_axis_pos => |j| {
                    try w.print("{{\"type\": \"joy_axis_pos\", \"axis\": {}}}", .{j.axis});
                },
            }
        } else {
            try w.print("null", .{});
        }
        if (i < bindings.len - 1) {
            try w.print(",", .{});
        }
        try w.print("\n", .{});
    }
}
