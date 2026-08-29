const std = @import("std");
const protobuf = @import("protobuf");

fn capnpPrefix(b: *std.Build) []const u8 {
    if (b.option([]const u8, "capnp-prefix", "Cap'n Proto install prefix")) |p| return p;
    const home = b.graph.environ_map.get("HOME") orelse "/usr/local";
    return b.fmt("{s}/.local", .{home});
}

/// Official libkj/libcapnp are GCC/libstdc++ archives. Zig's LLD does not
/// resolve their std::exception_ptr symbols even with -lstdc++. Build a
/// shared library with the system C++ compiler so those symbols are closed
/// inside the .so; Zig only links the C ABI.
fn buildCapnpShared(b: *std.Build, prefix: []const u8) std.Build.LazyPath {
    const inc = b.fmt("{s}/include", .{prefix});
    const lib = b.fmt("{s}/lib", .{prefix});
    const cxx = b.addSystemCommand(&.{ "c++", "-shared", "-fPIC", "-std=c++17" });
    cxx.setName("libzigcapnp.so");
    cxx.addArg("-I");
    cxx.addDirectoryArg(b.path("src/capnp"));
    cxx.addArg("-I");
    cxx.addDirectoryArg(b.path("src/gen/capnp"));
    cxx.addArg(b.fmt("-I{s}", .{inc}));
    cxx.addArg(b.fmt("-L{s}", .{lib}));
    cxx.addArg(b.fmt("-Wl,-rpath,{s}", .{lib}));
    cxx.addFileArg(b.path("src/capnp/capnp_bridge.cpp"));
    cxx.addFileArg(b.path("src/gen/capnp/benchmark.capnp.cpp"));
    cxx.addArg("-lcapnp");
    cxx.addArg("-lkj");
    cxx.addArg("-lstdc++");
    cxx.addArg("-lpthread");
    cxx.addArg("-ldl");
    cxx.addArg("-o");
    return cxx.addOutputFileArg("libzigcapnp.so");
}

fn applyCapnp(b: *std.Build, mod: *std.Build.Module, so: std.Build.LazyPath, prefix: []const u8) void {
    mod.addIncludePath(b.path("src/capnp"));
    mod.addLibraryPath(so.dirname());
    mod.addRPath(so.dirname());
    mod.addRPathSpecial("$ORIGIN/../lib");
    mod.addRPath(.{ .cwd_relative = b.fmt("{s}/lib", .{prefix}) });
    mod.linkSystemLibrary("zigcapnp", .{ .use_pkg_config = .no });
    mod.link_libc = true;
    mod.link_libcpp = false;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const capnp_prefix = capnpPrefix(b);

    const serde_dep = b.dependency("serde", .{ .target = target, .optimize = optimize });
    const zig_msgpack_dep = b.dependency("zig_msgpack", .{ .target = target, .optimize = optimize });
    const zbor_dep = b.dependency("zbor", .{ .target = target, .optimize = optimize });
    const msgpack_l_dep = b.dependency("msgpack_lalinsky", .{ .target = target, .optimize = optimize });
    const s2s_dep = b.dependency("s2s", .{ .target = target, .optimize = optimize });
    const protobuf_dep = b.dependency("protobuf", .{ .target = target, .optimize = optimize });
    const flatbuffers_dep = b.dependency("flatbuffers", .{ .target = target, .optimize = optimize });

    const gen_proto = b.step("gen-proto", "Generate Zig types from schemas/v2/protobuf/benchmark_v2.proto");
    const protoc_step = protobuf.RunProtocStep.create(protobuf_dep.builder, target, .{
        .destination_directory = b.path("src/gen"),
        .source_files = &.{b.path("../schemas/v2/protobuf/benchmark_v2.proto")},
        .include_directories = &.{b.path("../schemas/v2/protobuf")},
    });
    gen_proto.dependOn(&protoc_step.step);

    const imports = [_]std.Build.Module.Import{
        .{ .name = "serde", .module = serde_dep.module("serde") },
        .{ .name = "zig_msgpack", .module = zig_msgpack_dep.module("msgpack") },
        .{ .name = "zbor", .module = zbor_dep.module("zbor") },
        .{ .name = "msgpack_lalinsky", .module = msgpack_l_dep.module("msgpack") },
        .{ .name = "s2s", .module = s2s_dep.module("s2s") },
        .{ .name = "protobuf", .module = protobuf_dep.module("protobuf") },
        .{ .name = "flatbuffers", .module = flatbuffers_dep.module("flatbuffers") },
    };

    const capnp_so = buildCapnpShared(b, capnp_prefix);
    b.getInstallStep().dependOn(&b.addInstallLibFile(capnp_so, "libzigcapnp.so").step);

    const root = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &imports,
    });
    applyCapnp(b, root, capnp_so, capnp_prefix);

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

    const test_root = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &imports,
    });
    applyCapnp(b, test_root, capnp_so, capnp_prefix);
    const unit_tests = b.addTest(.{
        .root_module = test_root,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run harness tests");
    test_step.dependOn(&run_unit_tests.step);
}
