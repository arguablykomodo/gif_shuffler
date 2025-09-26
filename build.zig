const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const cpu_features = std.Target.wasm.featureSet(&.{
        .multivalue,
        .relaxed_simd,
        .simd128,
    });

    const wasm = b.addExecutable(.{
        .name = "gif_shuffler",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/wasm.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .wasm32,
                .os_tag = .freestanding,
                .cpu_features_add = cpu_features,
            }),
            .optimize = optimize,
        }),
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
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    b.step("test", "Run unit tests").dependOn(&run_unit_tests.step);

    const bench = b.addExecutable(.{
        .name = "bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bench.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const install_bench = b.addInstallArtifact(bench, .{});
    b.step("bench", "Build benchmark").dependOn(&install_bench.step);
}
