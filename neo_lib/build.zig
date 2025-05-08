const std = @import("std");

const Mode = enum {
    shared,
    static,
    wasm,
};

pub fn build(b: *std.Build) void {
    const optimize_native = b.standardOptimizeOption(.{});
    const target_native = b.standardTargetOptions(.{});

    const optimize_wasm = std.builtin.OptimizeMode.ReleaseSmall;
    const target_wasm = b.resolveTargetQuery(.{
        .os_tag = .freestanding,
        .cpu_arch = .wasm32,
        .cpu_features_add = std.Target.wasm.featureSet(&[_]std.Target.wasm.Feature{.multivalue}),
    });

    const root_path = b.path("src/neo.zig");

    const wasm_pages_max = b.option(u64, "wasm-pages-max", "Set the maximum number of pages accessible by wasm") orelse 1000;
    const wasm_pages_min = b.option(u64, "wasm-pages-min", "Set the minimum number of pages accessible by wasm") orelse 100;
    const mode_opt = b.option([]const u8, "mode", "Set the build mode for libneo") orelse "shared";

    const map = std.StaticStringMap(Mode).initComptime(.{
        .{ @tagName(Mode.shared), Mode.shared },
        .{ @tagName(Mode.static), Mode.static },
        .{ @tagName(Mode.wasm), Mode.wasm },
    });

    const mode = map.get(mode_opt) orelse Mode.shared;

    const neo_lib = switch (mode) {
        .shared => b.addSharedLibrary(.{
            .root_source_file = root_path,
            .optimize = optimize_native,
            .single_threaded = true,
            .target = target_native,
            .link_libc = true,
            .name = "neo",
        }),
        .static => b.addStaticLibrary(.{
            .root_source_file = root_path,
            .optimize = optimize_native,
            .target = target_native,
            .name = "neo",
        }),
        .wasm => b.addExecutable(.{
            .root_source_file = root_path,
            .optimize = optimize_wasm,
            .target = target_wasm,
            .name = "neo",
        }),
    };

    if (mode == .wasm) {
        neo_lib.entry = .disabled;
        neo_lib.rdynamic = true;

        neo_lib.import_memory = true;
        neo_lib.initial_memory = std.wasm.page_size * wasm_pages_min;
        neo_lib.max_memory = std.wasm.page_size * wasm_pages_max;
    }

    if (mode == .shared) {
        neo_lib.rdynamic = true;
    }

    const neo_install = b.addInstallArtifact(neo_lib, .{
        .dest_dir = .{ .override = .{ .custom = "lib" } },
    });

    b.default_step.dependOn(&neo_install.step);

    const test_step = b.step("test", "Run unit tests");

    const tests = b.addTest(.{
        .root_source_file = root_path,
        .target = target_native,
    });

    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);

    const check_step = b.step("check", "Check the library");
    check_step.dependOn(&neo_lib.step);
}
