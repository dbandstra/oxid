const build_options = @import("build_options");
const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const commands = @import("commands.zig");

const dirname = @import("root").pstorage_dirname;

pub const Recorder = struct {
    file: std.fs.File,
    frame_index: u32,
};

pub fn open(hunk_side: *HunkSide, game_seed: u32) !Recorder {
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

    const file_path = try std.fs.path.join(&hunk_side.allocator, &[_][]const u8{
        dir_path,
        "game0000", // TODO use timestamp or something
    });

    const file = try std.fs.cwd().createFile(file_path, .{});
    errdefer file.close();

    file.writer().print("demo {} {}\n", .{
        build_options.version,
        game_seed,
    }) catch |err| {
        @panic("aw man"); // FIXME
    };

    return Recorder{
        .file = file,
        .frame_index = 0,
    };
}

pub fn close(recorder: *Recorder) void {
    recorder.file.close();
}

pub fn recordInput(
    recorder: *Recorder,
    player_number: u32,
    command: commands.GameCommand,
    down: bool,
) void {
    recorder.file.writer().print("{} {} {} {}\n", .{
        recorder.frame_index,
        player_number,
        @tagName(command),
        down,
    }) catch |err| {
        @panic("whoops"); // FIXME
    };
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

pub fn openPlayer(hunk_side: *HunkSide) !Player {
    const mark = hunk_side.getMark();
    defer hunk_side.freeToMark(mark);

    const dir_path = try std.fs.getAppDataDir(
        &hunk_side.allocator,
        dirname ++ std.fs.path.sep_str ++ "recordings",
    );
    const file_path = try std.fs.path.join(&hunk_side.allocator, &[_][]const u8{
        dir_path,
        "game0000", // FIXME
    });

    const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
        //if (err == error.FileNotFound)
        //    return null;
        return err;
    };
    errdefer file.close();

    // read first line
    var buffer: [1024]u8 = undefined;
    const maybe_slice = file.reader().readUntilDelimiterOrEof(&buffer, '\n') catch |err| {
        @panic("dang it");
    };
    const slice = maybe_slice orelse @panic("no slice");
    // TODO ensure first word is 'demo'
    const space = std.mem.lastIndexOfScalar(u8, slice, ' ') orelse @panic("no space");
    const seed_slice = slice[space + 1 ..];
    const seed = std.fmt.parseInt(u32, seed_slice, 10) catch |err| {
        @panic("failed to parse seed");
    };

    // prepare first input
    var player: Player = .{
        .file = file,
        .game_seed = seed,
        .frame_index = 0,
        .next_input = null,
    };

    readNextInput(&player);

    return player;
}

pub fn closePlayer(player: *Player) void {
    player.file.close();
}

pub fn readNextInput(player: *Player) void {
    var buffer: [1024]u8 = undefined;
    const maybe_slice = player.file.reader().readUntilDelimiterOrEof(&buffer, '\n') catch |err| {
        @panic("dang it");
    };
    var slice = maybe_slice orelse {
        player.next_input = null;
        return;
    };
    var space = std.mem.indexOfScalar(u8, slice, ' ') orelse @panic("no space");
    const frame_index = std.fmt.parseInt(u32, slice[0..space], 10) catch |err| {
        @panic("failed to parse frame_index");
    };
    slice = slice[space + 1 ..];
    space = std.mem.indexOfScalar(u8, slice, ' ') orelse @panic("no space");
    const player_number = std.fmt.parseInt(u32, slice[0..space], 10) catch |err| {
        @panic("failed to parse player_number");
    };
    slice = slice[space + 1 ..];
    space = std.mem.indexOfScalar(u8, slice, ' ') orelse @panic("no space");
    const command = blk: {
        inline for (@typeInfo(commands.GameCommand).Enum.fields) |field, i| {
            if (std.mem.eql(u8, field.name, slice[0..space]))
                break :blk @intToEnum(commands.GameCommand, i);
        }
        @panic("failed to parse command");
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

pub fn readInput(player: *Player) ?InputEvent {
    var buffer: [1024]u8 = undefined;
    const maybe_slice = file.reader().readUntilDelimiterOrEof(&buffer, '\n') catch |err| {
        @panic("dang it");
    };
}
