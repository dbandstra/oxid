const builtin = @import("builtin");
const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const t = b.addTest("test.zig");
    t.addPackagePath("zig-hunk", "lib/zig-hunk/hunk.zig");

    const main = b.addExecutable("oxid", "src/main_sdl.zig");
    main.setOutputDir("zig-cache");
    main.setBuildMode(b.standardReleaseOptions());
    main.linkSystemLibrary("SDL2");
    main.linkSystemLibrary("epoxy");
    main.linkSystemLibrary("c");
    main.addPackagePath("zig-clap", "lib/zig-clap/clap.zig");
    addCommonRequirements(b, main);

    const wasm = b.addStaticLibrary("oxid", "src/main_web.zig");
    wasm.step.dependOn(&b.addExecutable("wasm_codegen", "tools/webgl_generate.zig").run().step);
    wasm.setOutputDir(".");
    wasm.setBuildMode(b.standardReleaseOptions());
    wasm.setTarget(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
        .abi = .none,
    });
    addCommonRequirements(b, wasm);

    b.step("test", "Run all tests").dependOn(&t.step);
    b.step("play", "Play the game").dependOn(&main.run().step);
    b.step("wasm", "Build WASM binary").dependOn(&wasm.step);
    b.default_step.dependOn(&main.step);
}

fn addCommonRequirements(b: *std.build.Builder, o: *std.build.LibExeObjStep) void {
    o.addPackagePath("zang", "lib/zang/src/zang.zig");
    o.addPackagePath("zig-hunk", "lib/zig-hunk/hunk.zig");
    o.addPackagePath("zig-pcx", "lib/zig-pcx/pcx.zig");
    o.addPackagePath("zig-wav", "lib/zig-wav/wav.zig");
    o.addPackagePath("gbe", "lib/gbe/gbe.zig");
    o.addPackagePath("pdraw", "src/platform/opengl/draw.zig");
    const assets_path = std.fs.path.join(b.allocator, &[_][]const u8{ b.build_root, "assets" });
    o.addBuildOption([]const u8, "assets_path", b.fmt("\"{}\"", .{assets_path}));
}
