const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const wasm_pages_max = b.option(u64, "wasm-pages-max", "Set the maximum number of pages accessible by wasm") orelse 100;
    const wasm_pages_min = b.option(u64, "wasm-pages-min", "Set the minimum number of pages accessible by wasm") orelse 10;
    const mode = b.option([]const u8, "mode", "Set the build mode for libneo") orelse "shared";

    const neo_lib_dep = b.dependency("neo-lib", .{
        .optimize = optimize,
        .target = target,
        .@"wasm-pages-max" = wasm_pages_max,
        .@"wasm-pages-min" = wasm_pages_min,
        .mode = mode,
    });

    const neo_lib_artifact = neo_lib_dep.artifact("neo");
    const neo_lib_install = b.addInstallArtifact(neo_lib_artifact, .{
        .dest_dir = .{ .override = .{ .custom = "lib" } },
    });

    const neo_lib_step = b.step("neo-lib", "Build libneo");
    neo_lib_step.dependOn(&neo_lib_install.step);

    const neo_explorer_dep = b.dependency("neo-explorer", .{
        .optimize = optimize,
        .target = target,
    });

    const neo_explorer_artifact = neo_explorer_dep.artifact("neo-explorer");
    const neo_explorer_install = b.addInstallArtifact(neo_explorer_artifact, .{});

    const neo_explorer_step = b.step("neo-explorer", "Build the Explorer");
    neo_explorer_step.dependOn(&neo_explorer_install.step);

    const neo_explorer_run_cmd = b.addRunArtifact(neo_explorer_artifact);
    const neo_explorer_run_step = b.step("run-explorer", "Run the Explorer");
    neo_explorer_run_step.dependOn(&neo_explorer_run_cmd.step);

    const neo_compiler_dep = b.dependency("neo-compiler", .{
        .optimize = optimize,
        .target = target,
        .mode = mode,
    });

    const neo_compiler_artifact = neo_compiler_dep.artifact("neo-compiler");
    const neo_compiler_install = b.addInstallArtifact(neo_compiler_artifact, .{});

    const neo_compiler_step = b.step("neo-compiler", "Build neo-compiler");
    neo_compiler_step.dependOn(&neo_compiler_install.step);

    const neo_compiler_run_cmd = b.addRunArtifact(neo_compiler_artifact);
    const neo_compiler_run_step = b.step("run-compiler", "Run the Compiler");
    neo_compiler_run_step.dependOn(&neo_compiler_run_cmd.step);
}
