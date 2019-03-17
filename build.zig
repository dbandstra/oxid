const Builder = @import("std").build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
  const mode = b.standardReleaseOptions();
  const windows = b.option(bool, "windows", "create windows build") orelse false;

  {
    var t = b.addTest("test.zig");
    t.linkSystemLibrary("c");
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&t.step);
  }

  {
    var exe = b.addExecutable("oxid", "src/main.zig");
    exe.setBuildMode(mode);

    if (windows) {
      exe.setTarget(builtin.Arch.x86_64, builtin.Os.windows, builtin.Abi.gnu);
    }

    exe.addPackagePath("zig-hunk", "zig-hunk/hunk.zig");
    exe.addPackagePath("zig-pcx", "zig-pcx/pcx.zig");

    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("epoxy");
    exe.linkSystemLibrary("c");

    b.default_step.dependOn(&exe.step);

    b.installArtifact(exe);

    const play = b.step("play", "Play the game");
    const run = exe.run();
    play.dependOn(&run.step);
  }
}
