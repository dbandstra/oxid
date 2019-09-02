const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const warn = @import("../warn.zig").warn;
const Key = @import("../common/key.zig").Key;
const input = @import("input.zig");

pub const Config = struct {
    volume: u32,
    menu_key_bindings: [@typeInfo(input.MenuCommand).Enum.fields.len]?Key,
    game_key_bindings: [@typeInfo(input.GameCommand).Enum.fields.len]?Key,
};

pub const default = Config {
    .volume = 100,
    .menu_key_bindings = blk: {
        var bindings: [@typeInfo(input.MenuCommand).Enum.fields.len]?Key = undefined;
        for (bindings) |*binding, i| {
            binding.* = switch (@intToEnum(input.MenuCommand, i)) {
                .Left => Key.Left,
                .Right => Key.Right,
                .Up => Key.Up,
                .Down => Key.Down,
                .Escape => Key.Escape,
                .Enter => Key.Return,
                .Yes => Key.Y,
                .No => Key.N,
            };
        }
        break :blk bindings;
    },
    .game_key_bindings = blk: {
        var bindings: [@typeInfo(input.GameCommand).Enum.fields.len]?Key = undefined;
        for (bindings) |*binding, i| {
            binding.* = switch (@intToEnum(input.GameCommand, i)) {
                .Up => Key.Up,
                .Down => Key.Down,
                .Left => Key.Left,
                .Right => Key.Right,
                .Shoot => Key.Space,
                .KillAllMonsters => Key.Backspace,
                .ToggleDrawBoxes => Key.F2,
                .ToggleGodMode => Key.F3,
                .Escape => Key.Escape,
            };
        }
        break :blk bindings;
    },
};

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
                            warn("Value of \"volume\" must be an integer\n");
                        },
                    }
                } else if (std.mem.eql(u8, kv.key, "menu_key_bindings")) {
                    readMenuKeyBindings(&cfg, kv.value);
                } else if (std.mem.eql(u8, kv.key, "game_key_bindings")) {
                    readGameKeyBindings(&cfg, kv.value);
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

fn readMenuKeyBindings(cfg: *Config, value: std.json.Value) void {
    switch (value) {
        .Object => |map| {
            var it = map.iterator();
            while (it.next()) |kv| {
                const command = parseMenuCommand(kv.key) orelse continue;
                cfg.menu_key_bindings[@enumToInt(command)] = parseKey(kv.value);
            }
        },
        else => {
            warn("Value of \"menu_key_bindings\" must be an object\n");
        },
    }
}

fn readGameKeyBindings(cfg: *Config, value: std.json.Value) void {
    switch (value) {
        .Object => |map| {
            var it = map.iterator();
            while (it.next()) |kv| {
                const command = parseGameCommand(kv.key) orelse continue;
                cfg.game_key_bindings[@enumToInt(command)] = parseKey(kv.value);
            }
        },
        else => {
            warn("Value of \"game_key_bindings\" must be an object\n");
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

fn parseKey(value: std.json.Value) ?Key {
    switch (value) {
        .String => |s| {
            inline for (@typeInfo(Key).Enum.fields) |field| {
                if (std.mem.eql(u8, s, field.name)) {
                    return @intToEnum(Key, field.value);
                }
            } else {
                warn("Unrecognized key: '{}'\n", s);
                return null;
            }
        },
        .Null => {
            return null;
        },
        else => {
            warn("Key binding value must be a string or null\n");
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
        \\    "menu_key_bindings": {{
        \\
    , cfg.volume);
    // don't bother with backslash escaping strings because we know none of
    // the possible values need it
    for (cfg.menu_key_bindings) |maybe_key, i| {
        const command = @intToEnum(input.MenuCommand, @intCast(@TagType(input.MenuCommand), i));
        const command_name = getEnumValueName(input.MenuCommand, command);
        try stream.print("        \"{}\": ", command_name);
        if (maybe_key) |key| {
            try stream.print("\"{}\"", getEnumValueName(Key, key));
        } else {
            try stream.print("null");
        }
        if (i < cfg.menu_key_bindings.len - 1) {
            try stream.print(",");
        }
        try stream.print("\n");
    }
    try stream.print(
        \\    }},
        \\    "game_key_bindings": {{
        \\
    );
    for (cfg.game_key_bindings) |maybe_key, i| {
        const command = @intToEnum(input.GameCommand, @intCast(@TagType(input.GameCommand), i));
        const command_name = getEnumValueName(input.GameCommand, command);
        try stream.print("        \"{}\": ", command_name);
        if (maybe_key) |key| {
            try stream.print("\"{}\"", getEnumValueName(Key, key));
        } else {
            try stream.print("null");
        }
        if (i < cfg.game_key_bindings.len - 1) {
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
