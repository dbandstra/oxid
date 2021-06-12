const build_options = @import("build_options");
const builtin = @import("builtin");
const std = @import("std");
const commands = @import("commands.zig");

fn parseVersion(string: []const u8) ?[2]u16 {
    var it = std.mem.tokenize(string, ".");
    const major_str = it.next() orelse return null;
    const major = std.fmt.parseInt(u16, major_str, 10) catch return null;
    const minor_str = it.next() orelse return null;
    const minor = std.fmt.parseInt(u16, minor_str, 10) catch return null;
    return [2]u16{ major, minor };
}

pub const Recorder = struct {
    frame_index: u32 = 0, // starts at 0 and counts up for every game frame
    last_frame_index: u32 = 0, // what frame_index was last time we recorded a command

    pub fn start(self: *Recorder, writer: anytype, seed: u32, is_multiplayer: bool) !void {
        try writer.writeAll("OXIDDEMO");
        if (parseVersion(build_options.version)) |version| {
            try writer.writeIntLittle(u16, version[0]);
            try writer.writeIntLittle(u16, version[1]);
        } else {
            try writer.writeIntLittle(u16, 0);
            try writer.writeIntLittle(u16, 0);
        }
        try writer.writeIntLittle(u32, seed);
        try writer.writeIntLittle(u32, @as(u32, if (is_multiplayer) 2 else 1));
        // add a placeholder for the scores. we'll go back and fill this in
        // when recording is complete
        try writer.writeIntLittle(u32, 0); // player 1 score
        try writer.writeIntLittle(u32, 0); // player 2 score
    }

    // write a special marker so we know on what frame to end the demo.
    pub fn end(self: *Recorder, writer: anytype) !void {
        // as long as outside code doesn't mess with these fields, this should
        // never happen
        std.debug.assert(self.frame_index >= self.last_frame_index);

        const rel_frame = self.frame_index - self.last_frame_index;

        // similarly, this shouldn't happen either. the incrementFrameIndex
        // function takes care of this situation
        std.debug.assert(rel_frame < 256);

        try writer.writeByte(254); // end of demo
        try writer.writeByte(@intCast(u8, rel_frame));
    }

    pub fn patchScore(self: *Recorder, buffer: []u8, score1: u32, score2: u32) void {
        // player 1 score
        buffer[20] = @truncate(u8, score1);
        buffer[21] = @truncate(u8, score1 >> 8);
        buffer[22] = @truncate(u8, score1 >> 16);
        buffer[23] = @truncate(u8, score1 >> 24);
        // player 2 score
        buffer[24] = @truncate(u8, score2);
        buffer[25] = @truncate(u8, score2 >> 8);
        buffer[26] = @truncate(u8, score2 >> 16);
        buffer[27] = @truncate(u8, score2 >> 24);
    }

    // call this at the end of every game frame
    pub fn incrementFrameIndex(self: *Recorder, writer: anytype) !void {
        self.frame_index = try std.math.add(u32, self.frame_index, 1);

        // as long as outside code doesn't mess with these fields, this should
        // never happen
        std.debug.assert(self.frame_index >= self.last_frame_index);

        // if we just hit 256 frames since the last recorded command, write
        // a no-op command. we only have one byte to store the frame offset
        if (self.frame_index - self.last_frame_index > 255) {
            try writer.writeByte(0); // no-op
            try writer.writeByte(255);
            self.last_frame_index += 255;
        }
    }

    pub fn recordInput(
        self: *Recorder,
        writer: anytype,
        player_index: u32,
        command: commands.GameCommand,
        down: bool,
    ) !void {
        // we only have 5 bits to store the command (32 possible values)
        comptime std.debug.assert(@typeInfo(commands.GameCommand).Enum.fields.len < 32);

        if (player_index > 1)
            return error.InvalidPlayerIndex;

        // as long as outside code doesn't mess with these fields, this should
        // never happen
        std.debug.assert(self.frame_index >= self.last_frame_index);

        const rel_frame = self.frame_index - self.last_frame_index;

        // similarly, this shouldn't happen either. the incrementFrameIndex
        // function takes care of this situation
        std.debug.assert(rel_frame < 256);

        try writer.writeByte(1 |
            (@intCast(u8, player_index) << 1) |
            (@as(u8, @boolToInt(down)) << 2) |
            (@as(u8, @enumToInt(command)) << 3));
        try writer.writeByte(@intCast(u8, rel_frame));

        self.last_frame_index = self.frame_index;
    }
};

pub const Player = struct {
    pub const Event = union(enum) {
        end_of_demo,
        input: struct {
            player_index: u32,
            command: commands.GameCommand,
            down: bool,
        },
    };

    file: if (builtin.arch == .wasm32) void else std.fs.File,
    game_seed: u32,
    is_multiplayer: bool,
    frame_index: u32,
    last_frame_index: u32,
    next: struct {
        frame_index: u32,
        event: Event,
    },

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

        if (parseVersion(build_options.version)) |oxid_ver| {
            if (parseVersion(version_string)) |demo_ver| {
                if (oxid_ver[0] != demo_ver[0] or oxid_ver[1] != demo_ver[1]) {
                    std.log.err("incompatible version (demo {}.{}.x, oxid {}.{}.x)", .{
                        demo_ver[0], demo_ver[1],
                        oxid_ver[0], oxid_ver[1],
                    });
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

        // the demo file contains the final scores, but we don't use those for anything (they're
        // just for the convenience of outside scripts). skip them
        try reader.skipBytes(8, .{});

        var player: Player = .{
            .file = file,
            .game_seed = seed,
            .is_multiplayer = is_multiplayer,
            .frame_index = 0,
            .last_frame_index = 0,
            .next = undefined, // set by readNextInput (below)
        };

        try readNextInput(&player);

        return player;
    }

    pub fn close(player: *Player) void {
        if (builtin.arch == .wasm32)
            return;

        player.file.close();
    }

    pub fn incrementFrameIndex(player: *Player) !void {
        if (builtin.arch == .wasm32)
            return error.NotSupported;

        player.frame_index = try std.math.add(u32, player.frame_index, 1);
    }

    pub fn readNextInput(player: *Player) !void {
        if (builtin.arch == .wasm32)
            return error.NotSupported;

        const byte0 = try player.file.reader().readByte();
        const byte1 = try player.file.reader().readByte();

        const frame_index = player.last_frame_index + @as(u32, byte1);

        if (byte0 == 254) { // end of demo
            player.next = .{
                .frame_index = frame_index,
                .event = .end_of_demo,
            };
        } else if (byte0 & 1 != 0) { // if 0 then this is a no-op (syncing the frame offset)
            const player_index = (byte0 & 2) >> 1;
            const down = (byte0 & 4) != 0;
            const command_index = byte0 >> 3;
            if (command_index >= @typeInfo(commands.GameCommand).Enum.fields.len)
                return error.InvalidDemo;
            const i = @intCast(@TagType(commands.GameCommand), command_index);
            const command = @intToEnum(commands.GameCommand, i);

            player.next = .{
                .frame_index = frame_index,
                .event = .{
                    .input = .{
                        .player_index = player_index,
                        .command = command,
                        .down = down,
                    },
                },
            };
        }

        player.last_frame_index = frame_index;
    }

    pub fn getNextEvent(player: *const Player) ?Event {
        if (player.next.frame_index == player.frame_index)
            return player.next.event;
        return null;
    }
};
