const builtin = @import("builtin");
const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const version = try getVersion(b.allocator);
    defer b.allocator.free(version);

    const t = b.addTest("test.zig");
    t.addPackagePath("zig-hunk", "lib/zig-hunk/hunk.zig");

    const zangc = b.addExecutable("zangc", "lib/zang/tools/zangc.zig");
    zangc.setBuildMode(b.standardReleaseOptions());
    zangc.setOutputDir("zig-cache");
    zangc.addPackagePath("zangscript", "lib/zang/src/zangscript.zig");
    const compile_zangscript = zangc.run();
    compile_zangscript.addArgs(&[_][]const u8{ "-o", "src/oxid/audio/generated.zig", "src/oxid/audio/script.txt" });

    const main = b.addExecutable("oxid", "src/main_sdl.zig");
    main.step.dependOn(&compile_zangscript.step);
    main.setOutputDir("zig-cache");
    main.setBuildMode(b.standardReleaseOptions());
    main.linkSystemLibrary("SDL2");
    main.linkSystemLibrary("c");
    main.addPackagePath("zig-clap", "lib/zig-clap/clap.zig");
    main.addBuildOption([]const u8, "version", version);
    try addCommonRequirements(b, main);

    const wasm = b.addStaticLibrary("oxid", "src/main_web.zig");
    wasm.step.dependOn(&compile_zangscript.step);
    wasm.step.dependOn(&b.addExecutable("wasm_codegen", "tools/webgl_generate.zig").run().step);
    wasm.setOutputDir("zig-cache");
    wasm.setBuildMode(b.standardReleaseOptions());
    wasm.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding, .abi = .none });
    wasm.addBuildOption([]const u8, "version", version);
    try addCommonRequirements(b, wasm);

    b.step("test", "Run all tests").dependOn(&t.step);
    b.step("play", "Play the game").dependOn(&main.run().step);
    b.step("wasm", "Build WASM binary").dependOn(&wasm.step);
    b.default_step.dependOn(&main.step);
}

fn addCommonRequirements(b: *std.build.Builder, o: *std.build.LibExeObjStep) !void {
    o.addPackagePath("gl", "lib/gl.zig");
    o.addPackagePath("zang", "lib/zang/src/zang.zig");
    o.addPackagePath("zig-hunk", "lib/zig-hunk/hunk.zig");
    o.addPackagePath("zig-pcx", "lib/zig-pcx/pcx.zig");
    o.addPackagePath("zig-wav", "lib/zig-wav/wav.zig");
    o.addPackagePath("gbe", "lib/gbe/gbe.zig");
    o.addPackagePath("pdraw", "src/platform/opengl/draw.zig");
    const assets_path = try std.fs.path.join(b.allocator, &[_][]const u8{ b.build_root, "assets" });
    o.addBuildOption([]const u8, "assets_path", assets_path);
}

fn getVersion(allocator: *std.mem.Allocator) ![]const u8 {
    const argv = &[_][]const u8{ "git", "describe", "--tags" };
    const child = try std.ChildProcess.init(argv, allocator);
    defer child.deinit();

    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    const version = try child.stdout.?.reader().readAllAlloc(allocator, 1024);
    errdefer allocator.free(version);

    switch (try child.wait()) {
        .Exited => return version,
        else => return error.UncleanExit,
    }
}
