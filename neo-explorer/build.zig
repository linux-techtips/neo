const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const wasm_pages_max = b.option(u64, "wasm-pages-max", "Set the maximum number of pages accessible by wasm") orelse 100;
    const wasm_pages_min = b.option(u64, "wasm-pages-min", "Set the minimum number of pages accessible by wasm") orelse 10;

    const neo_lib_dep = b.dependency("neo-lib", .{
        .optimize = optimize,
        .target = target,
        .@"wasm-pages-max" = wasm_pages_max,
        .@"wasm-pages-min" = wasm_pages_min,
        .mode = @as([]const u8, "wasm"),
    });

    const neo_lib_artifact = neo_lib_dep.artifact("neo");
    const neo_lib_install = b.addInstallArtifact(neo_lib_artifact, .{
        .dest_dir = .{ .override = .{ .custom = "lib" } },
    });

    const neo_explorer_exe = b.addExecutable(.{
        .root_source_file = b.path("src/main.zig"),
        .name = "neo-explorer",
        .optimize = optimize,
        .target = target,
    });

    neo_explorer_exe.step.dependOn(&neo_lib_install.step);
    neo_explorer_exe.root_module.addAnonymousImport("neo", .{
        // TODO: Factor out hardcoed path.
        .root_source_file = b.path("zig-out/lib/neo.wasm"),
    });

    b.installArtifact(neo_explorer_exe);

    const run_cmd = b.addRunArtifact(neo_explorer_exe);
    run_cmd.step.dependOn(&neo_lib_install.step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the explorer");
    run_step.dependOn(&run_cmd.step);
}
