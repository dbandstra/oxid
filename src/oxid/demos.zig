const build_options = @import("build_options");
const builtin = @import("builtin");
const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const commands = @import("commands.zig");

const dirname = @import("root").pstorage_dirname;

// note: demos don't work in the wasm build yet. in order to get that working
// the `file` field needs to be moved to the caller's responsibility

pub const Recorder = struct {
    file: if (builtin.arch == .wasm32) void else std.fs.File,
    frame_index: u32, // starts at 0 and counts up for every game frame
    last_frame_index: u32, // what frame_index was last time we recorded a command

    pub fn open(hunk_side: *HunkSide, seed: u32, is_multiplayer: bool) !Recorder {
        if (builtin.arch == .wasm32)
            return error.NotSupported;

        // i don't think zig's std library has any date functionality, so pull in libc.
        // TODO push date code to main file and use via @import("root")?
        const c = @cImport({
            @cInclude("time.h");
        });

        const mark = hunk_side.getMark();
        defer hunk_side.freeToMark(mark);

        const dir_path = try std.fs.getAppDataDir(
            &hunk_side.allocator,
            dirname ++ std.fs.path.sep_str ++ "recordings",
        );

        std.fs.cwd().makeDir(dir_path) catch |err| {
            if (err != error.PathAlreadyExists)
                return err;
        };

        const file_path = blk: {
            var buffer: [40]u8 = undefined;
            var fbs = std.io.fixedBufferStream(&buffer);
            var stream = fbs.outStream();

            var t = c.time(null);
            var tm: *c.tm = c.localtime(&t) orelse return error.FailedToGetLocalTime;

            _ = try stream.print("demo_{d:0>4}-{d:0>2}-{d:0>2}_{d:0>2}-{d:0>2}-{d:0>2}.oxiddemo", .{
                // cast to unsigned because zig is weird and prints '+' characters
                // before all signed numbers
                (try std.math.cast(u32, tm.tm_year)) + 1900,
                (try std.math.cast(u32, tm.tm_mon)) + 1,
                try std.math.cast(u32, tm.tm_mday),
                try std.math.cast(u32, tm.tm_hour),
                try std.math.cast(u32, tm.tm_min),
                try std.math.cast(u32, tm.tm_sec),
            });

            break :blk try std.fs.path.join(&hunk_side.allocator, &[_][]const u8{
                dir_path,
                fbs.getWritten(),
            });
        };

        std.log.notice("Recording to {s}", .{file_path});

        const file = try std.fs.cwd().createFile(file_path, .{});
        errdefer file.close();

        try file.writer().writeAll("OXIDDEMO");
        try file.writer().writeIntLittle(u32, build_options.version.len);
        try file.writer().writeAll(build_options.version);
        try file.writer().writeIntLittle(u32, seed);
        try file.writer().writeIntLittle(u32, @as(u32, if (is_multiplayer) 2 else 1));

        return Recorder{
            .file = file,
            .frame_index = 0,
            .last_frame_index = 0,
        };
    }

    pub fn close(recorder: *Recorder) void {
        if (builtin.arch == .wasm32)
            return;

        recorder.file.close();
    }

    pub fn recordInput(
        recorder: *Recorder,
        player_index: u32,
        command: commands.GameCommand,
        down: bool,
    ) !void {
        // we only have 5 bits to store the command
        comptime std.debug.assert(@typeInfo(commands.GameCommand).Enum.fields.len < 32);

        if (builtin.arch == .wasm32)
            return error.NotSupported;

        if (player_index > 1)
            return error.InvalidPlayerIndex;

        if (recorder.frame_index < recorder.last_frame_index)
            return error.InvalidFrameIndex;

        // byte 1, bit 1: player_index
        // byte 1, bit 2: down
        const byte_base = @intCast(u8, player_index) | (@as(u8, @boolToInt(down)) << 1);

        // byte 2 will contain the number of frames since the last command. but if
        // more frames have elapsed than fit in the byte, we need to emit no-op
        // commands to keep the integrity of the relative frame offsets.
        // byte 1, bit 3: no-op (bits 4-8 are unused)
        var rel_frame = recorder.frame_index - recorder.last_frame_index;
        while (rel_frame > 255) : (rel_frame -= 255) {
            try recorder.file.writer().writeByte(byte_base | 4);
            try recorder.file.writer().writeByte(255);
        }

        // byte 1, bits 4-8: command
        try recorder.file.writer().writeByte(byte_base | (@as(u8, @enumToInt(command)) << 3));
        // byte 2: relative frame offset
        try recorder.file.writer().writeByte(@intCast(u8, rel_frame));

        recorder.last_frame_index = recorder.frame_index;
    }
};

pub const Player = struct {
    pub const InputEvent = struct {
        frame_index: u32,
        player_index: u32,
        command: commands.GameCommand,
        down: bool,
    };

    file: if (builtin.arch == .wasm32) void else std.fs.File,
    game_seed: u32,
    is_multiplayer: bool,
    frame_index: u32,
    last_frame_index: u32,
    next_input: ?InputEvent,

    fn parseVersion(string: []const u8) ?[3][]const u8 {
        var it = std.mem.tokenize(string, ".-");
        const major = it.next() orelse return null;
        const minor = it.next() orelse return null;
        const patch = it.next() orelse return null;
        return [3][]const u8{ major, minor, patch };
    }

    // we accept the demo if major and minor versions are same, but the patch
    // version can differ. this is under the assumption that any "breaking"
    // changes to gamecode, however slight, will incur at least a minor version
    // bump.
    fn areVersionsCompatible(a: [3][]const u8, b: [3][]const u8) bool {
        return std.mem.eql(u8, a[0], b[0]) and std.mem.eql(u8, a[1], b[1]);
    }

    pub fn open(filename: []const u8) !Player {
        if (builtin.arch == .wasm32)
            return error.NotSupported;

        const file = try std.fs.cwd().openFile(filename, .{});
        errdefer file.close();

        var buffer: [128]u8 = undefined;
        file.reader().readNoEof(buffer[0..8]) catch |err| {
            if (err == error.EndOfStream) return error.NotADemo;
            return err;
        };
        if (!std.mem.eql(u8, buffer[0..8], "OXIDDEMO")) return error.NotADemo;

        const version_len = try file.reader().readIntLittle(u32);
        if (version_len > buffer.len) return error.InvalidDemo;
        const version_string = buffer[0..version_len];
        try file.reader().readNoEof(version_string);

        if (parseVersion(build_options.version)) |oxid_version| {
            if (parseVersion(version_string)) |demo_version| {
                if (!areVersionsCompatible(oxid_version, demo_version)) {
                    std.log.err("incompatible version (demo {}, oxid {})", .{ version_string, build_options.version });
                    return error.DemoVersionMismatch;
                }
            } else {
                std.log.warn("could not parse demo version, skipping compatibility check", .{});
            }
        } else {
            std.log.warn("could not determine oxid version, skipping compatibility check", .{});
        }

        const seed = try file.reader().readIntLittle(u32);
        const is_multiplayer = (try file.reader().readIntLittle(u32)) > 1;

        var player: Player = .{
            .file = file,
            .game_seed = seed,
            .is_multiplayer = is_multiplayer,
            .frame_index = 0,
            .last_frame_index = 0,
            .next_input = null,
        };

        // prepare first input
        try readNextInput(&player);

        return player;
    }

    pub fn close(player: *Player) void {
        if (builtin.arch == .wasm32)
            return;

        player.file.close();
    }

    pub fn readNextInput(player: *Player) !void {
        if (builtin.arch == .wasm32)
            return error.NotSupported;

        const byte0 = try player.file.reader().readByte();
        const byte1 = try player.file.reader().readByte();

        const frame_index = player.last_frame_index + @as(u32, byte1);

        const player_index = byte0 & 1;
        const down = (byte0 & 2) != 0;
        if (byte0 & 4 == 0) { // third bit means no-op
            const command_index = byte0 >> 3;
            if (command_index >= @typeInfo(commands.GameCommand).Enum.fields.len)
                return error.InvalidDemo;
            const i = @intCast(@TagType(commands.GameCommand), command_index);
            const command = @intToEnum(commands.GameCommand, i);

            player.next_input = .{
                .frame_index = frame_index,
                .player_index = player_index,
                .command = command,
                .down = down,
            };
        }

        player.last_frame_index = frame_index;
    }
};
