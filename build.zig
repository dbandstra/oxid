const Builder = @import("std").build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
  const mode = b.standardReleaseOptions();

  var t = b.addTest("test.zig");
  t.linkSystemLibrary("c");
  const test_step = b.step("test", "Run all tests");
  test_step.dependOn(&t.step);

  var exe = b.addExecutable("oxid", "src/main.zig");
  exe.addPackagePath("zig-pcx", "zig-pcx/pcx.zig");
  exe.addPackagePath("zigutils", "zigutils/src/index.zig");
  exe.setBuildMode(mode);
  exe.addIncludeDir("/usr/local/include"); // where to find SDL2 and epoxy headers
  exe.linkSystemLibrary("SDL2");
  exe.linkSystemLibrary("epoxy");
  exe.linkSystemLibrary("c");

  b.installArtifact(exe);

  b.default_step.dependOn(&exe.step);

  const play = b.step("play", "Play the game");
  const run = b.addCommand(".", b.env_map, [][]const u8{ exe.getOutputPath() });
  play.dependOn(&run.step);
  run.step.dependOn(&exe.step);
}
