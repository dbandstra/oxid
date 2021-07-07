const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    // Get the version
    const version = blk: {
        const argv = &[_][]const u8{ "git", "describe", "--tags" };
        var code: u8 = undefined;
        const stdout = b.execAllowFail(argv, &code, .Ignore) catch |err| {
            if (err == error.ExitCodeFailure)
                break :blk ""; // no tags yet - shouldn't cause the build to fail
            return err;
        };
        break :blk std.mem.trim(u8, stdout, " \n\r");
    };

    // Unit tests
    {
        const t = b.addTest("test.zig");
        t.addPackagePath("zig-hunk", "lib/zig-hunk/hunk.zig");

        b.step("test", "Run all tests").dependOn(&t.step);
    }

    //const zangc = b.addExecutable("zangc", "lib/zang/tools/zangc.zig");
    //zangc.setBuildMode(b.standardReleaseOptions());
    //zangc.setOutputDir("zig-cache");
    //zangc.addPackagePath("zangscript", "lib/zang/src/zangscript.zig");
    //const compile_zangscript = zangc.run();
    //compile_zangscript.addArgs(&.{
    //    "-o",
    //    "src/oxid/audio/generated.zig",
    //    "src/oxid/audio/script.txt",
    //});

    // SDL + OpenGL frontend
    {
        const exe = b.addExecutable("oxid_sdl_opengl", "src/main_sdl_opengl.zig");
        //exe.step.dependOn(&compile_zangscript.step);
        exe.setBuildMode(b.standardReleaseOptions());
        exe.install();
        exe.linkLibC();
        exe.linkSystemLibrary("SDL2");
        try addCommonRequirements(b, exe);
        exe.addBuildOption([]const u8, "version", version);
        exe.addPackagePath("zig-clap", "lib/zig-clap/clap.zig");
        exe.addPackagePath("gl", "lib/gl.zig");

        b.step("sdl_opengl", "Build with SDL+OpenGL").dependOn(&exe.install_step.?.step);

        const play = exe.run();
        play.step.dependOn(&exe.install_step.?.step);
        if (b.args) |args|
            play.addArgs(args);

        b.step("play", "Play the game").dependOn(&play.step);
    }

    // SDL_Renderer frontend
    {
        const exe = b.addExecutable("oxid_sdl_renderer", "src/main_sdl_renderer.zig");
        //exe.step.dependOn(&compile_zangscript.step);
        exe.setBuildMode(b.standardReleaseOptions());
        exe.install();
        exe.linkLibC(); // what's the difference between this and linkSystemLibrary("c")?
        exe.linkSystemLibrary("SDL2");
        try addCommonRequirements(b, exe);
        exe.addBuildOption([]const u8, "version", version);

        b.step("sdl_renderer", "Build with SDL_Renderer").dependOn(&exe.install_step.?.step);
    }

    // WebAssembly frontend
    {
        const lib = b.addSharedLibrary("oxid", "src/main_web.zig", .unversioned);
        //lib.step.dependOn(&compile_zangscript.step);
        lib.setBuildMode(b.standardReleaseOptions());
        lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
        lib.install();
        try addCommonRequirements(b, lib);
        lib.addBuildOption([]const u8, "version", version);
        lib.addPackagePath("zig-webgl", "lib/zig-webgl/generated/webgl.zig");

        b.step("wasm", "Build WebAssembly binary").dependOn(&lib.install_step.?.step);
    }

    // Command-line demo verification tool
    {
        const exe = b.addExecutable("verifydemo", "src/verifydemo.zig");
        exe.setBuildMode(b.standardReleaseOptions());
        exe.install();
        try addCommonRequirements(b, exe);
        exe.addBuildOption([]const u8, "version", version);

        b.step("verifydemo", "Build verifydemo utility").dependOn(&exe.install_step.?.step);
    }

    // Default step is top-level install (builds and installs everything).
}

fn addCommonRequirements(b: *std.build.Builder, o: *std.build.LibExeObjStep) !void {
    o.addPackagePath("zang", "lib/zang/src/zang.zig");
    o.addPackagePath("modules", "lib/zang/src/modules.zig");
    o.addPackagePath("zig-hunk", "lib/zig-hunk/hunk.zig");
    o.addPackagePath("zig-pcx", "lib/zig-pcx/pcx.zig");
    o.addPackagePath("zig-wav", "lib/zig-wav/wav.zig");
    o.addPackagePath("gbe", "lib/gbe/gbe.zig");
    const assets_path = try std.fs.path.join(b.allocator, &.{ b.build_root, "assets" });
    o.addBuildOption([]const u8, "assets_path", assets_path);
}
