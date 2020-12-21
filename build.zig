const builtin = @import("builtin");
const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const t = b.addTest("test.zig");
    t.addPackagePath("zig-hunk", "lib/zig-hunk/hunk.zig");

    const write_version = b.addExecutable("write_version", "tools/write_version.zig").run();

    const zangc = b.addExecutable("zangc", "lib/zang/tools/zangc.zig");
    zangc.setBuildMode(b.standardReleaseOptions());
    zangc.setOutputDir("zig-cache");
    zangc.addPackagePath("zangscript", "lib/zang/src/zangscript.zig");
    const compile_zangscript = zangc.run();
    compile_zangscript.addArgs(&[_][]const u8{ "-o", "src/oxid/audio/generated.zig", "src/oxid/audio/script.txt" });

    const main = b.addExecutable("oxid", "src/main_sdl.zig");
    main.step.dependOn(&compile_zangscript.step);
    main.step.dependOn(&write_version.step);
    main.setOutputDir("zig-cache");
    main.setBuildMode(b.standardReleaseOptions());
    main.linkSystemLibrary("SDL2");
    main.linkSystemLibrary("c");
    main.addPackagePath("zig-clap", "lib/zig-clap/clap.zig");
    try addCommonRequirements(b, main);

    const wasm = b.addStaticLibrary("oxid", "src/main_web.zig");
    main.step.dependOn(&compile_zangscript.step);
    wasm.step.dependOn(&write_version.step);
    wasm.step.dependOn(&b.addExecutable("wasm_codegen", "tools/webgl_generate.zig").run().step);
    wasm.setOutputDir("zig-cache");
    wasm.setBuildMode(b.standardReleaseOptions());
    wasm.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding, .abi = .none });
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
