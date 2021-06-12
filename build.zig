const builtin = @import("builtin");
const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const version = try getVersion(b);

    const t = b.addTest("test.zig");
    t.addPackagePath("zig-hunk", "lib/zig-hunk/hunk.zig");

    const zangc = b.addExecutable("zangc", "lib/zang/tools/zangc.zig");
    zangc.setBuildMode(b.standardReleaseOptions());
    zangc.setOutputDir("zig-cache");
    zangc.addPackagePath("zangscript", "lib/zang/src/zangscript.zig");
    const compile_zangscript = zangc.run();
    compile_zangscript.addArgs(&[_][]const u8{
        "-o",
        "src/oxid/audio/generated.zig",
        "src/oxid/audio/script.txt",
    });

    const main = b.addExecutable("oxid", "src/main_sdl_opengl.zig");
    main.step.dependOn(&compile_zangscript.step);
    main.setBuildMode(b.standardReleaseOptions());
    main.setOutputDir("zig-cache");
    main.linkSystemLibrary("SDL2");
    main.linkSystemLibrary("c");
    try addCommonRequirements(b, main);
    main.addBuildOption([]const u8, "version", version);
    main.addPackagePath("zig-clap", "lib/zig-clap/clap.zig");
    main.addPackagePath("gl", "lib/gl.zig");

    const main_alt = b.addExecutable("oxid", "src/main_sdl_renderer.zig");
    main_alt.step.dependOn(&compile_zangscript.step);
    main_alt.setBuildMode(b.standardReleaseOptions());
    main_alt.setOutputDir("zig-cache");
    main_alt.linkSystemLibrary("SDL2");
    main_alt.linkSystemLibrary("c");
    try addCommonRequirements(b, main_alt);
    main_alt.addBuildOption([]const u8, "version", version);

    const wasm = b.addStaticLibrary("oxid", "src/main_web.zig");
    wasm.step.dependOn(&compile_zangscript.step);
    wasm.setBuildMode(b.standardReleaseOptions());
    wasm.setOutputDir("zig-cache");
    wasm.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding, .abi = .none });
    try addCommonRequirements(b, wasm);
    wasm.addBuildOption([]const u8, "version", version);
    wasm.addPackagePath("zig-webgl", "lib/zig-webgl/generated/webgl.zig");

    const verifydemo = b.addExecutable("verifydemo", "src/verifydemo.zig");
    verifydemo.setBuildMode(b.standardReleaseOptions());
    verifydemo.setOutputDir("zig-cache");
    // FIXME we should only require gbe, not zang etc.
    try addCommonRequirements(b, verifydemo);
    verifydemo.addBuildOption([]const u8, "version", version);

    b.step("test", "Run all tests").dependOn(&t.step);
    b.step("play", "Play the game").dependOn(&main.run().step);
    b.step("sdl_renderer", "Build with SDL_Renderer").dependOn(&main_alt.step);
    b.step("wasm", "Build WASM binary").dependOn(&wasm.step);
    b.step("verifydemo", "Build verifydemo utility").dependOn(&verifydemo.step);
    b.default_step.dependOn(&main.step);
}

fn addCommonRequirements(b: *std.build.Builder, o: *std.build.LibExeObjStep) !void {
    o.addPackagePath("zang", "lib/zang/src/zang.zig");
    o.addPackagePath("modules", "lib/zang/src/modules.zig");
    o.addPackagePath("zig-hunk", "lib/zig-hunk/hunk.zig");
    o.addPackagePath("zig-pcx", "lib/zig-pcx/pcx.zig");
    o.addPackagePath("zig-wav", "lib/zig-wav/wav.zig");
    o.addPackagePath("gbe", "lib/gbe/gbe.zig");
    const assets_path = try std.fs.path.join(b.allocator, &[_][]const u8{
        b.build_root,
        "assets",
    });
    o.addBuildOption([]const u8, "assets_path", assets_path);
}

fn getVersion(b: *std.build.Builder) ![]const u8 {
    const argv = &[_][]const u8{ "git", "describe", "--tags" };
    var code: u8 = undefined;
    const stdout = b.execAllowFail(argv, &code, .Ignore) catch |err| {
        if (err == error.ExitCodeFailure)
            return ""; // no tags yet - shouldn't cause the build to fail
        return err;
    };
    return std.mem.trim(u8, stdout, " \n\r");
}
