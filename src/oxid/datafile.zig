const builtin = @import("builtin");
const std = @import("std");
const HunkSide = @import("zigutils").HunkSide;

const Mode = enum{
  Read,
  Write,
};

fn openDataFile(hunk_side: *HunkSide, filename: []const u8, mode: Mode) !std.os.File {
  const mark = hunk_side.getMark();
  defer hunk_side.freeToMark(mark);

  const dir_path = blk: {
    if (builtin.os == builtin.Os.windows) {
      const appdata = try std.os.getEnvVarOwned(&hunk_side.allocator, "APPDATA");
      break :blk try std.os.path.join(&hunk_side.allocator, [][]const u8{appdata, "Oxid"});
    } else {
      const home = try std.os.getEnvVarOwned(&hunk_side.allocator, "HOME");
      break :blk try std.os.path.join(&hunk_side.allocator, [][]const u8{home, ".oxid"});
    }
  };

  if (mode == Mode.Write) {
    std.os.makeDir(dir_path) catch |err| {
      if (err != error.PathAlreadyExists) {
        return err;
      }
    };
  }

  const file_path = try std.os.path.join(&hunk_side.allocator, [][]const u8{dir_path, filename});

  return switch (mode) {
    Mode.Read => std.os.File.openRead(file_path),
    Mode.Write => std.os.File.openWrite(file_path),
  };
}

pub fn loadHighScore(hunk_side: *HunkSide) !u32 {
  const file = openDataFile(hunk_side, "highscore.dat", Mode.Read) catch |err| {
    if (err == error.FileNotFound) {
      return u32(0);
    }
    return err;
  };
  defer file.close();

  var fis = std.os.File.inStream(file);

  return fis.stream.readIntLittle(u32);
}

pub fn saveHighScore(hunk_side: *HunkSide, high_score: u32) !void {
  const file = try openDataFile(hunk_side, "highscore.dat", Mode.Write);
  defer file.close();

  var fos = std.os.File.outStream(file);

  try fos.stream.writeIntLittle(u32, high_score);
}
