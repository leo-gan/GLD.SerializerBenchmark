const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const serde_dep = b.dependency("serde", .{ .target = target, .optimize = optimize });
    const zig_msgpack_dep = b.dependency("zig_msgpack", .{ .target = target, .optimize = optimize });
    const zbor_dep = b.dependency("zbor", .{ .target = target, .optimize = optimize });
    const msgpack_l_dep = b.dependency("msgpack_lalinsky", .{ .target = target, .optimize = optimize });
    const s2s_dep = b.dependency("s2s", .{ .target = target, .optimize = optimize });

    const imports = [_]std.Build.Module.Import{
        .{ .name = "serde", .module = serde_dep.module("serde") },
        .{ .name = "zig_msgpack", .module = zig_msgpack_dep.module("msgpack") },
        .{ .name = "zbor", .module = zbor_dep.module("zbor") },
        .{ .name = "msgpack_lalinsky", .module = msgpack_l_dep.module("msgpack") },
        .{ .name = "s2s", .module = s2s_dep.module("s2s") },
    };

    const root = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &imports,
    });

    const exe = b.addExecutable(.{
        .name = "serializer-benchmark-zig",
        .root_module = root,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the benchmark");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &imports,
        }),
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run harness tests");
    test_step.dependOn(&run_unit_tests.step);
}
