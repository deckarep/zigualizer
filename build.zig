const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("zigualizer", .{ .root_source_file = b.path("src/fft.zig") });

    const example_name = b.option(
        []const u8,
        "example-name",
        "Build and install a single example",
    );

    const example_install = b.option(
        bool,
        "example",
        "Install the example binaries to zig-out/example",
    ) orelse (example_name != null);

    // Examples
    _ = try exampleTargets(b, target, optimize, example_install, example_name);
}

fn exampleTargets(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    install: bool,
    install_name: ?[]const u8,
) !void {
    // Ignore if we're not installing
    if (!install) return;

    // Open the directory
    const dir_path = "./examples";
    var dir = try std.Io.Dir.cwd().openDir(b.graph.io, dir_path, .{ .iterate = true });
    defer dir.close(b.graph.io);

    // Go through and add each as a step
    var dir_it = dir.iterate();
    while (try dir_it.next(b.graph.io)) |entry| {
        // Get the index of the last '.' so we can strip the extension.
        const index = std.mem.lastIndexOfScalar(u8, entry.name, '.') orelse continue;
        if (index == 0) continue;

        // If we have specified a specific name, only install that one.
        if (install_name) |n| {
            if (!std.mem.eql(u8, n, entry.name)) continue;
        }

        // Name of the app and full path to the entrypoint.
        const name = entry.name[0..index];
        const path = try std.fs.path.join(b.allocator, &[_][]const u8{
            dir_path,
            entry.name,
        });

        const exe = b.addExecutable(.{
            .name = name,
            .root_module = b.createModule(.{
                .root_source_file = .{ .cwd_relative = path },
                .target = target,
                .optimize = optimize,
            }),
        });

        const raylib_path = "libs/raylib-6.0_macos/";

        // For examples, link Raylib and any other C deps.
        exe.root_module.addObjectFile(b.path(raylib_path ++ "lib/libraylib.a"));
        exe.root_module.addIncludePath(b.path(raylib_path ++ "include"));

        exe.root_module.linkFramework("CoreVideo", .{});
        exe.root_module.linkFramework("IOKit", .{});
        exe.root_module.linkFramework("Cocoa", .{});
        exe.root_module.linkFramework("GLUT", .{});
        exe.root_module.linkFramework("OpenGL", .{});

        exe.root_module.linkSystemLibrary("c", .{});

        exe.root_module.addImport("zigualizer", b.modules.get("zigualizer").?);
        if (install) {
            const install_step = b.addInstallArtifact(exe, .{
                .dest_dir = .{ .override = .{ .custom = "example" } },
            });
            b.getInstallStep().dependOn(&install_step.step);
        }

        // If we have specified a specific name, only install that one.
        if (install_name) |_| break;
    } else {
        if (install_name) |n| {
            std.debug.print("No example file named: {s}\n", .{n});
            std.debug.print("Choices:\n", .{});
            var c_dir_it2 = dir.iterate();
            while (try c_dir_it2.next(b.graph.io)) |entry| {
                std.debug.print("\t{s}\n", .{entry.name});
            }
            return error.InvalidExampleName;
        }
    }
}
