const std = @import("std");
const Builder = std.build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const windows = b.option(bool, "windows", "create windows build") orelse false;
    const wasm = b.option(bool, "wasm", "create wasm build") orelse false;

    {
        var t = b.addTest("test.zig");
        t.linkSystemLibrary("c");
        t.addPackagePath("zig-hunk", "lib/zig-hunk/hunk.zig");
        const test_step = b.step("test", "Run all tests");
        test_step.dependOn(&t.step);
    }

    var main: *std.build.LibExeObjStep = undefined;

    if (wasm) {
        main = b.addStaticLibrary("oxid", "src/main_web.zig");
        main.setOutputDir(".");
        main.setBuildMode(mode);
        main.setTarget(.wasm32, .freestanding, .none);

        // run tool to generate a few source files related to webgl
        const webgl_generate_tool = b.addExecutable("webgl_generate", "tools/webgl_generate.zig");
        const run_webgl_generate_tool = webgl_generate_tool.run();
        main.step.dependOn(&run_webgl_generate_tool.step);
    } else {
        main = b.addExecutable("oxid", "src/main_sdl.zig");
        main.setOutputDir("zig-cache");
        main.setBuildMode(mode);

        if (windows) {
            main.setTarget(.x86_64, .windows, .gnu);
        }

        main.linkSystemLibrary("SDL2");
        main.linkSystemLibrary("epoxy");
        main.linkSystemLibrary("c");

        main.addPackagePath("zig-clap", "lib/zig-clap/clap.zig");
    }

    main.addPackagePath("zang", "lib/zang/src/zang.zig");
    main.addPackagePath("zig-hunk", "lib/zig-hunk/hunk.zig");
    main.addPackagePath("zig-pcx", "lib/zig-pcx/pcx.zig");
    main.addPackagePath("zig-wav", "lib/zig-wav/wav.zig");
    main.addPackagePath("gbe", "lib/gbe/src/gbe.zig");

    main.addPackagePath("pdraw", "src/platform/opengl/draw.zig");

    const assets_path = std.fs.path.join(b.allocator, [_][]const u8{b.build_root, "assets"});
    main.addBuildOption([]const u8, "assets_path", b.fmt("\"{}\"", assets_path));

    b.default_step.dependOn(&main.step);
    b.installArtifact(main);

    if (!wasm) {
        const play = b.step("play", "Play the game");
        const run = main.run();
        play.dependOn(&run.step);
    }
}
