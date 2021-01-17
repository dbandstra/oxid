const build_options = @import("build_options");
const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const commands = @import("commands.zig");

const dirname = @import("root").pstorage_dirname;

pub const Recorder = struct {
    file: std.fs.File,
    frame_index: u32,
};

pub fn open(hunk_side: *HunkSide) !Recorder {
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

    file.writer().print("demo {} {}\n", .{
        build_options.version,
        0, // FIXME - print random seed
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
