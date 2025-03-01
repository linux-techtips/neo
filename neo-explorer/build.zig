const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const wasm_pages_max = b.option(u64, "wasm-pages-max", "Set the maximum number of pages accessible by wasm") orelse 1000;
    const wasm_pages_min = b.option(u64, "wasm-pages-min", "Set the minimum number of pages accessible by wasm") orelse 100;

    const neo_lib_dep = b.dependency("neo-lib", .{
        .optimize = optimize,
        .target = target,
        .@"wasm-pages-max" = wasm_pages_max,
        .@"wasm-pages-min" = wasm_pages_min,
        .mode = @as([]const u8, "wasm"),
    });

    const neo_lib_artifact = neo_lib_dep.artifact("neo");
    const neo_lib_install = b.addInstallArtifact(neo_lib_artifact, .{
        // TODO: This should not be hard-coded.
        .dest_dir = .{ .override = .{ .custom = "../public" } },
    });

    const run_cmd = b.addSystemCommand(&.{ "bun", "run", "server.js" });
    run_cmd.step.dependOn(&neo_lib_install.step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the explorer");
    run_step.dependOn(&run_cmd.step);
}
