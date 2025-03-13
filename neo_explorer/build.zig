const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const wasm_pages_max = b.option(u64, "wasm-pages-max", "Set the maximum number of pages accessible by wasm") orelse 1000;
    const wasm_pages_min = b.option(u64, "wasm-pages-min", "Set the minimum number of pages accessible by wasm") orelse 100;

    const root_path = b.path("src/main.zig");

    const neo_explorer = b.addExecutable(.{
        .root_source_file = root_path,
        .optimize = optimize,
        .target = target,
        .name = "neo-explorer",
    });

    const neo_lib_dep = b.dependency("neo_lib", .{
        .optimize = optimize,
        .target = target,
        .@"wasm-pages-max" = wasm_pages_max,
        .@"wasm-pages-min" = wasm_pages_min,
        .mode = @as([]const u8, "wasm"),
    });

    const neo_lib_artifact = neo_lib_dep.artifact("neo");
    const neo_lib_install = b.addInstallArtifact(neo_lib_artifact, .{
        // TODO: This should not be hard-coded.
        .dest_dir = .{ .override = .{ .custom = "bundle" } },
    });

    neo_explorer.step.dependOn(&neo_lib_install.step);

    const httpz = b.dependency("httpz", .{
        .target = target,
        .optimize = optimize,
    });

    neo_explorer.root_module.addImport("httpz", httpz.module("httpz"));

    const bundle_cmd = b.addSystemCommand(&.{ "bun", "build", "./public/index.html", "--outdir=zig-out/bundle", "--chunk-naming=[name].[ext]" });
    neo_explorer.step.dependOn(&bundle_cmd.step);

    b.getInstallStep().dependOn(&neo_explorer.step);

    const run_cmd = b.addRunArtifact(neo_explorer);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the server");
    run_step.dependOn(&run_cmd.step);

    var dir = try std.fs.cwd().openDir("zig-out/bundle", .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(b.allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        const path = try std.fs.path.join(b.allocator, &.{ "zig-out/bundle", entry.path });
        neo_explorer.root_module.addAnonymousImport(entry.path, .{
            .root_source_file = b.path(path),
        });
    }
}
