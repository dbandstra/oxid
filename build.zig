const std = @import("std");
const Builder = std.build.Builder;
const builtin = @import("builtin");

// run `zig build -wasm` to build wasm

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const windows = b.option(bool, "windows", "create windows build") orelse false;
    const wasm = b.option(bool, "wasm", "create wasm build") orelse false;

    {
        var t = b.addTest("test.zig");
        t.linkSystemLibrary("c");
        const test_step = b.step("test", "Run all tests");
        test_step.dependOn(&t.step);
    }

    if (wasm) {
        const lib = b.addStaticLibrary("oxid", "src/oxid_web.zig");
        lib.setOutputDir(".");
        lib.setBuildMode(mode);
        lib.setTarget(.wasm32, .freestanding, .none);

        lib.addPackagePath("gbe", "gbe/src/gbe.zig");
        lib.addPackagePath("pdraw", "src/platform/opengl/draw.zig");
        lib.addPackagePath("zang", "zang/src/zang.zig");
        lib.addPackagePath("zig-hunk", "zig-hunk/hunk.zig");
        lib.addPackagePath("zig-pcx", "zig-pcx/pcx.zig");

        const assets_path = std.fs.path.join(b.allocator, [_][]const u8{b.build_root, "assets"});
        lib.addBuildOption([]const u8, "assets_path", b.fmt("\"{}\"", assets_path));

        // run this tool first. it will generate some code in the src/generated folder
        const webgl_generate_tool = b.addExecutable("webgl_generate", "tools/webgl_generate.zig");
        const run_webgl_generate_tool = webgl_generate_tool.run();
        lib.step.dependOn(&run_webgl_generate_tool.step);

        b.default_step.dependOn(&lib.step);
        b.installArtifact(lib);
    } else {
        var exe = b.addExecutable("oxid", "src/oxid.zig");
        exe.setBuildMode(mode);

        if (windows) {
            exe.setTarget(.x86_64, .windows, .gnu);
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
