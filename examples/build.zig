const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "raylib-example",
        .root_source_file = b.path("raylib.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.addObjectFile(b.path("../libs/raylib-5.5_macos/lib/libraylib.a"));
    exe.addIncludePath(b.path("../libs/raylib-5.5_macos/include"));

    exe.linkFramework("CoreVideo");
    exe.linkFramework("IOKit");
    exe.linkFramework("Cocoa");
    exe.linkFramework("GLUT");
    exe.linkFramework("OpenGL");

    exe.linkSystemLibrary("c");

    // Resolve the 'library' dependency.
    const zigualizer_dep = b.dependency("zigualizer", .{});
    exe.root_module.addImport("zigualizer", zigualizer_dep.module("zigualizer"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
