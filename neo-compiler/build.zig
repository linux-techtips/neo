const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const mode = b.option([]const u8, "mode", "Set the build mode for libneo") orelse "shared";

    const neo_lib_dep = b.dependency("neo-lib", .{
        .optimize = optimize,
        .target = target,
        .@"wasm-pages-max" = 0,
        .@"wasm-pages-min" = 0,
        .mode = mode,
    });

    const neo_lib_artifact = neo_lib_dep.artifact("neo");
    const neo_lib_install = b.addInstallArtifact(neo_lib_artifact, .{});

    const neo_compiler_exe = b.addExecutable(.{
        .root_source_file = b.path("src/main.zig"),
        .name = "neo-compiler",
        .optimize = optimize,
        .target = target,
    });

    if (!std.mem.eql(u8, mode, "wasm")) neo_compiler_exe.linkLibrary(neo_lib_artifact);

    neo_compiler_exe.step.dependOn(&neo_lib_install.step);
    b.installArtifact(neo_compiler_exe);

    const run_cmd = b.addRunArtifact(neo_compiler_exe);
    run_cmd.step.dependOn(&neo_lib_install.step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the explorer");
    run_step.dependOn(&run_cmd.step);
}
