const builtin = @import("builtin");
const std = @import("std");
const StackAllocator = @import("../../zigutils/src/traits/StackAllocator.zig").StackAllocator;

const Mode = enum{
  Read,
  Write,
};

fn openDataFile(stack: *StackAllocator, filename: []const u8, mode: Mode) !std.os.File {
  const mark = stack.get_mark();
  defer stack.free_to_mark(mark);

  const dir_path = blk: {
    if (builtin.os == builtin.Os.windows) {
      const appdata = try std.os.getEnvVarOwned(&stack.allocator, "APPDATA");
      break :blk try std.os.path.join(&stack.allocator, appdata, "Oxid");
    } else {
      const home = try std.os.getEnvVarOwned(&stack.allocator, "HOME");
      break :blk try std.os.path.join(&stack.allocator, home, ".oxid");
    }
  };

  if (mode == Mode.Write) {
    std.os.makeDir(dir_path) catch |err| {
      if (err != error.PathAlreadyExists) {
        return err;
      }
    };
  }

  const file_path = try std.os.path.join(&stack.allocator, dir_path, filename);

  return switch (mode) {
    Mode.Read => std.os.File.openRead(file_path),
    Mode.Write => std.os.File.openWrite(file_path),
  };
}

pub fn loadHighScore(stack: *StackAllocator) !u32 {
  const file = openDataFile(stack, "highscore.dat", Mode.Read) catch |err| {
    if (err == error.FileNotFound) {
      return u32(0);
    }
    return err;
  };
  defer file.close();

  var fis = std.os.File.inStream(file);

  return fis.stream.readIntLe(u32);
}

pub fn saveHighScore(stack: *StackAllocator, high_score: u32) !void {
  const file = try openDataFile(stack, "highscore.dat", Mode.Write);
  defer file.close();

  var fos = std.os.File.outStream(file);

  try fos.stream.writeIntLe(u32, high_score);
}
