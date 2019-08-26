const std = @import("std");
const Builder = std.build.Builder;
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
        var exe = b.addExecutable("oxid", "src/oxid.zig");
        exe.setBuildMode(mode);

        if (windows) {
            exe.setTarget(builtin.Arch.x86_64, builtin.Os.windows, builtin.Abi.gnu);
        }

        exe.addPackagePath("gbe", "gbe/src/gbe.zig");
        exe.addPackagePath("pdraw", "src/platform/opengl/draw.zig");
        exe.addPackagePath("zang", "zang/src/zang.zig");
        exe.addPackagePath("zig-hunk", "zig-hunk/hunk.zig");
        exe.addPackagePath("zig-pcx", "zig-pcx/pcx.zig");
        exe.addPackagePath("zig-wav", "zig-wav/wav.zig");

        exe.linkSystemLibrary("SDL2");
        exe.linkSystemLibrary("epoxy");
        exe.linkSystemLibrary("c");

        const assets_path = std.fs.path.join(b.allocator, [_][]const u8{b.build_root, "assets"});
        exe.addBuildOption([]const u8, "assets_path", b.fmt("\"{}\"", assets_path));

        exe.setOutputDir("zig-cache");

        b.default_step.dependOn(&exe.step);

        b.installArtifact(exe);

        const play = b.step("play", "Play the game");
        const run = exe.run();
        play.dependOn(&run.step);
    }
}
