const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const root_path = b.path("src/main.zig");

    const neo_compiler = b.addExecutable(.{
        .root_source_file = root_path,
        .optimize = optimize,
        .target = target,
        .name = "neo",
    });

    const neo_lib_dep = b.dependency("neo_lib", .{
        .optimize = optimize,
        .target = target,
        .mode = @as([]const u8, "shared"),
    });

    const neo_lib_artifact = neo_lib_dep.artifact("neo");
    const neo_lib_install = b.addInstallArtifact(neo_lib_artifact, .{});

    neo_compiler.linkLibrary(neo_lib_artifact);
    neo_compiler.step.dependOn(&neo_lib_install.step);

    b.installArtifact(neo_compiler);

    const run_cmd = b.addRunArtifact(neo_compiler);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the server");
    run_step.dependOn(&run_cmd.step);

    const check_step = b.step("check", "Check the source code");
    check_step.dependOn(&neo_compiler.step);
}
