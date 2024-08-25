const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const cpu_features = std.Target.wasm.featureSet(&.{
        .multivalue,
        .relaxed_simd,
        .simd128,
    });

    const wasm = b.addExecutable(.{
        .name = "gif_shuffler",
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
            .cpu_features_add = cpu_features,
        }),
        .optimize = optimize,
        .root_source_file = b.path("src/main.zig"),
    });
    wasm.entry = .disabled;
    wasm.rdynamic = true;

    const install_wasm = b.addInstallArtifact(wasm, .{ .dest_dir = .{ .override = .prefix } });
    b.getInstallStep().dependOn(&install_wasm.step);

    const install_static = b.addInstallDirectory(.{
        .source_dir = b.path("static"),
        .install_dir = .prefix,
        .install_subdir = "",
    });
    b.getInstallStep().dependOn(&install_static.step);

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
