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
        .dest_dir = .{ .override = .{ .custom = "../public" } },
    });

    neo_explorer.step.dependOn(&neo_lib_install.step);

    const httpz = b.dependency("httpz", .{
        .target = target,
        .optimize = optimize,
    });

    neo_explorer.root_module.addImport("httpz", httpz.module("httpz"));

    // TODO: Yet another bun feature I cannot use because it is undercooked.
    // https://github.com/oven-sh/bun/issues/16335
    const bundle_cmd = b.addSystemCommand(&.{ "bun", "build", "./public/index.html", "./public/neo.wasm", "--outdir=zig-out/bundle", "--chunk-naming=[name].[ext]", "--asset-naming=[name].[ext]" });
    // Thank you random ass undocumented stupid build flag that no one ever talks about that actually makes the build command run.
    bundle_cmd.has_side_effects = true;
    _ = bundle_cmd.captureStdOut();

    neo_explorer.step.dependOn(&bundle_cmd.step);
    b.installArtifact(neo_explorer);

    const run_cmd = b.addRunArtifact(neo_explorer);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the server");
    run_step.dependOn(&run_cmd.step);

    inline for (.{ "index.html", "index.css", "index.js", "neo.wasm" }) |entry| {
        const path = try std.fs.path.join(b.allocator, &.{ "zig-out/bundle", entry });
        neo_explorer.root_module.addAnonymousImport(entry, .{
            .root_source_file = b.path(path),
        });
    }
}
