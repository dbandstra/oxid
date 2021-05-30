const build_options = @import("build_options");
const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const commands = @import("commands.zig");

const dirname = @import("root").pstorage_dirname;

pub const Recorder = struct {
    file: std.fs.File,
    frame_index: u32,
};

pub fn openRecorder(hunk_side: *HunkSide, game_seed: u32) !Recorder {
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

    // TODO also encode whether it's a multiplayer game
    try file.writer().print("demo {} {}\n", .{
        build_options.version,
        game_seed,
    });

    return Recorder{
        .file = file,
        .frame_index = 0,
    };
}

pub fn closeRecorder(recorder: *Recorder) void {
    recorder.file.close();
}

pub fn recordInput(
    recorder: *Recorder,
    player_number: u32,
    command: commands.GameCommand,
    down: bool,
) !void {
    try recorder.file.writer().print("{} {} {} {}\n", .{
        recorder.frame_index,
        player_number,
        @tagName(command),
        down,
    });
}

pub const Player = struct {
    file: std.fs.File,
    game_seed: u32,
    frame_index: u32,
    next_input: ?InputEvent,
};

pub const InputEvent = struct {
    frame_index: u32,
    player_number: u32,
    command: commands.GameCommand,
    down: bool,
};

pub fn openPlayer(filename: []const u8) !Player {
    const file = try std.fs.cwd().openFile(filename, .{});
    errdefer file.close();

    // read first line
    var buffer: [1024]u8 = undefined;
    const maybe_slice = try file.reader().readUntilDelimiterOrEof(&buffer, '\n');
    const slice = maybe_slice orelse return error.InvalidDemo;
    // TODO ensure first word is 'demo'
    const space = std.mem.lastIndexOfScalar(u8, slice, ' ') orelse return error.InvalidDemo;
    const seed_slice = slice[space + 1 ..];
    const seed = std.fmt.parseInt(u32, seed_slice, 10) catch return error.InvalidDemo;

    // TODO check version and fail if it doesn't equal build_options.version.

    // prepare first input
    var player: Player = .{
        .file = file,
        .game_seed = seed,
        .frame_index = 0,
        .next_input = null,
    };

    try readNextInput(&player);

    return player;
}

pub fn closePlayer(player: *Player) void {
    player.file.close();
}

pub fn readNextInput(player: *Player) !void {
    var buffer: [1024]u8 = undefined;
    const maybe_slice = try player.file.reader().readUntilDelimiterOrEof(&buffer, '\n');
    var slice = maybe_slice orelse {
        player.next_input = null;
        return;
    };
    var space = std.mem.indexOfScalar(u8, slice, ' ') orelse return error.InvalidDemo;
    const frame_index = std.fmt.parseInt(u32, slice[0..space], 10) catch return error.InvalidDemo;
    slice = slice[space + 1 ..];
    space = std.mem.indexOfScalar(u8, slice, ' ') orelse return error.InvalidDemo;
    const player_number = std.fmt.parseInt(u32, slice[0..space], 10) catch return error.InvalidDemo;
    slice = slice[space + 1 ..];
    space = std.mem.indexOfScalar(u8, slice, ' ') orelse return error.InvalidDemo;
    const command = blk: {
        inline for (@typeInfo(commands.GameCommand).Enum.fields) |field, i| {
            if (std.mem.eql(u8, field.name, slice[0..space]))
                break :blk @intToEnum(commands.GameCommand, i);
        }
        return error.InvalidDemo;
    };
    slice = slice[space + 1 ..];
    // this crashes the compiler (TODO file an issue)
    //var down: bool = undefined;
    //if (std.mem.eql(u8, "true", slice))
    //    down = true;
    //if (std.mem.eql(u8, "false", slice))
    //    down = false;
    const down = slice[0] == 't';
    //@panic("failed to parse down");
    //break :blk false;
    player.next_input = .{
        .frame_index = frame_index,
        .player_number = player_number,
        .command = command,
        .down = down,
    };
}
