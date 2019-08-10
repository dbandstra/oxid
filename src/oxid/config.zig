const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const Key = @import("../common/key.zig").Key;
const input = @import("input.zig");

pub const Config = struct {
    muted: bool,
    menu_key_bindings: [@typeInfo(input.MenuCommand).Enum.fields.len]?Key,
    game_key_bindings: [@typeInfo(input.GameCommand).Enum.fields.len]?Key,
};

const config_datadir = "Oxid";
const config_filename = "config.json";

const default_config = Config {
    .muted = false,
    .menu_key_bindings = blk: {
        var bindings: [@typeInfo(input.MenuCommand).Enum.fields.len]?Key = undefined;
        for (bindings) |*binding, i| {
            binding.* = switch (@intToEnum(input.MenuCommand, i)) {
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

pub fn load(hunk_side: *HunkSide) !Config {
    const mark = hunk_side.getMark();
    defer hunk_side.freeToMark(mark);

    var config = default_config;

    const dir_path = try std.fs.getAppDataDir(&hunk_side.allocator, config_datadir);
    const file_path = try std.fs.path.join(&hunk_side.allocator, [_][]const u8{dir_path, config_filename});
    const contents = std.io.readFileAlloc(&hunk_side.allocator, file_path) catch |err| {
        if (err == error.FileNotFound) {
            return config;
        }
        return err;
    };

    var p = std.json.Parser.init(&hunk_side.allocator, false);
    defer p.deinit();

    var tree = try p.parse(contents);
    defer tree.deinit();

    switch (tree.root) {
        .Object => |map| {
            var it = map.iterator();
            while (it.next()) |kv| {
                if (std.mem.eql(u8, kv.key, "muted")) {
                    config.muted = switch (kv.value) {
                        .Bool => |v| v,
                        else => return error.ConfigError,
                    };
                } else {
                    std.debug.warn("Unrecognized config field: '{}'\n", kv.key);
                }
            }
        },
        else => return error.ConfigError,
    }

    return config;
}

pub fn save(config: Config, hunk_side: *HunkSide) !void {
    const mark = hunk_side.getMark();
    defer hunk_side.freeToMark(mark);

    const dir_path = try std.fs.getAppDataDir(&hunk_side.allocator, config_datadir);

    std.fs.makeDir(dir_path) catch |err| {
        if (err != error.PathAlreadyExists) {
            return err;
        }
    };

    const file_path = try std.fs.path.join(&hunk_side.allocator, [_][]const u8{dir_path, config_filename});

    const file = try std.fs.File.openWrite(file_path);
    defer file.close();

    var fos = std.fs.File.outStream(file);

    try fos.stream.print(
        \\{{
        \\    "muted": {}
        \\}}
        \\
    , config.muted);
}
