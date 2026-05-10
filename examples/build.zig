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

    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("src/c.h"),
        .target = target,
        .optimize = optimize,
    });

    const raylib_path = "../libs/raylib-6.0_macos/";

    translate_c.linkSystemLibrary("c", .{});
    translate_c.addIncludePath(b.path(raylib_path ++ "include"));

    const exe = b.addExecutable(.{
        .name = "raylib-example",
        .root_module = b.createModule(.{
            .root_source_file = .{ .cwd_relative = "src/main.zig" },
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "c",
                    .module = translate_c.createModule(),
                },
            },
        }),
    });

    exe.root_module.addObjectFile(b.path(raylib_path ++ "lib/libraylib.a"));

    exe.root_module.linkFramework("CoreVideo", .{});
    exe.root_module.linkFramework("IOKit", .{});
    exe.root_module.linkFramework("Cocoa", .{});
    exe.root_module.linkFramework("GLUT", .{});
    exe.root_module.linkFramework("OpenGL", .{});

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
