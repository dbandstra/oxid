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
    frame_index: u32,
};

pub fn openRecorder(hunk_side: *HunkSide, seed: u32, is_multiplayer: bool) !Recorder {
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

        _ = try stream.print("demo_{d:0>4}-{d:0>2}-{d:0>2}_{d:0>2}-{d:0>2}-{d:0>2}.txt", .{
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

    try file.writer().print("oxid_demo {} {} {}\n", .{
        build_options.version, seed, is_multiplayer,
    });

    return Recorder{
        .file = file,
        .frame_index = 0,
    };
}

pub fn closeRecorder(recorder: *Recorder) void {
    if (builtin.arch == .wasm32)
        return;

    recorder.file.close();
}

pub fn recordInput(
    recorder: *Recorder,
    player_number: u32,
    command: commands.GameCommand,
    down: bool,
) !void {
    if (builtin.arch == .wasm32)
        return error.NotSupported;

    try recorder.file.writer().print("{} {} {} {}\n", .{
        recorder.frame_index,
        player_number,
        @tagName(command),
        down,
    });
}

const LineParser = struct {
    it: std.mem.TokenIterator,

    fn init(line: []const u8) LineParser {
        return .{ .it = std.mem.tokenize(line, " ") };
    }

    fn nextToken(self: *LineParser) ?[]const u8 {
        return self.it.next();
    }

    fn expectToken(self: *LineParser, line_no: u32, comptime name: []const u8) ![]const u8 {
        return self.nextToken() orelse {
            std.log.debug("line {}: expected {}, found end of line", .{ line_no, name });
            return error.InvalidDemo;
        };
    }

    fn expectEndOfLine(self: *LineParser, line_no: u32) !void {
        if (self.nextToken()) |token| {
            std.log.debug("line {}: expected end of line, found '{}'", .{ line_no, token });
            return error.InvalidDemo;
        }
    }

    fn parseInt(self: *LineParser, comptime T: type, line_no: u32, comptime name: []const u8) !T {
        const token = try self.expectToken(line_no, name);
        return std.fmt.parseInt(u32, token, 10) catch {
            std.log.debug("line {}: {}: expected int, found '{}'", .{ line_no, name, token });
            return error.InvalidDemo;
        };
    }

    fn parseEnum(self: *LineParser, comptime T: type, line_no: u32, comptime name: []const u8) !T {
        const token = try self.expectToken(line_no, name);
        inline for (@typeInfo(T).Enum.fields) |field, i| {
            if (std.mem.eql(u8, field.name, token))
                return @intToEnum(T, i);
        }
        std.log.debug("line {}: {}: invalid value '{}'", .{ line_no, name, token });
        return error.InvalidDemo;
    }

    fn parseBool(self: *LineParser, line_no: u32, comptime name: []const u8) !bool {
        const token = try self.expectToken(line_no, name);
        if (std.mem.eql(u8, token, "false")) return false;
        if (std.mem.eql(u8, token, "true")) return true;
        std.log.debug("line {}: {}: expected bool, found '{}'", .{ line_no, name, token });
        return error.InvalidDemo;
    }
};

pub const Player = struct {
    file: if (builtin.arch == .wasm32) void else std.fs.File,
    line_no: u32,
    game_seed: u32,
    is_multiplayer: bool,
    frame_index: u32,
    next_input: ?InputEvent,
};

pub const InputEvent = struct {
    frame_index: u32,
    player_number: u32,
    command: commands.GameCommand,
    down: bool,
};

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

pub fn openPlayer(filename: []const u8) !Player {
    if (builtin.arch == .wasm32)
        return error.NotSupported;

    const file = try std.fs.cwd().openFile(filename, .{});
    errdefer file.close();

    // read first line
    var buffer: [128]u8 = undefined;
    const line = (try file.reader().readUntilDelimiterOrEof(&buffer, '\n')) orelse
        return error.NotADemo;
    var p = LineParser.init(line);

    // parse identifier
    if (if (p.nextToken()) |token| !std.mem.eql(u8, token, "oxid_demo") else true) {
        std.log.debug("not an oxid demo", .{});
        return error.InvalidDemo;
    }

    // parse version
    const version_string = try p.expectToken(1, "version");
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

    const seed = try p.parseInt(u32, 1, "seed");
    const is_multiplayer = try p.parseBool(1, "is_multiplayer");

    try p.expectEndOfLine(1);

    var player: Player = .{
        .file = file,
        .line_no = 2,
        .game_seed = seed,
        .is_multiplayer = is_multiplayer,
        .frame_index = 0,
        .next_input = null,
    };

    // prepare first input
    try readNextInput(&player);

    return player;
}

pub fn closePlayer(player: *Player) void {
    if (builtin.arch == .wasm32)
        return;

    player.file.close();
}

pub fn readNextInput(player: *Player) !void {
    if (builtin.arch == .wasm32)
        return error.NotSupported;

    var buffer: [128]u8 = undefined;
    const line = (try player.file.reader().readUntilDelimiterOrEof(&buffer, '\n')) orelse {
        player.next_input = null;
        return;
    };
    var p = LineParser.init(line);

    const frame_index = try p.parseInt(u32, player.line_no, "frame_index");
    const player_number = try p.parseInt(u32, player.line_no, "player_number");
    const command = try p.parseEnum(commands.GameCommand, player.line_no, "command");
    const down = try p.parseBool(player.line_no, "down");

    try p.expectEndOfLine(player.line_no);

    player.next_input = .{
        .frame_index = frame_index,
        .player_number = player_number,
        .command = command,
        .down = down,
    };
    player.line_no += 1;
}
