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
    const dir_path = (comptime thisDir()) ++ "/examples";
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    // Go through and add each as a step
    var dir_it = dir.iterate();
    while (try dir_it.next()) |entry| {
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
            .root_source_file = .{ .cwd_relative = path },
            .target = target,
            .optimize = optimize,
        });

        // For examples, link Raylib and any other C deps.
        exe.addObjectFile(b.path("libs/raylib-5.5_macos/lib/libraylib.a"));
        exe.addIncludePath(b.path("libs/raylib-5.5_macos/include"));

        exe.linkFramework("CoreVideo");
        exe.linkFramework("IOKit");
        exe.linkFramework("Cocoa");
        exe.linkFramework("GLUT");
        exe.linkFramework("OpenGL");

        exe.linkSystemLibrary("c");

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
            while (try c_dir_it2.next()) |entry| {
                std.debug.print("\t{s}\n", .{entry.name});
            }
            return error.InvalidExampleName;
        }
    }
}

/// Path to the directory with the build.zig.
fn thisDir() []const u8 {
    return std.fs.path.dirname(@src().file) orelse unreachable;
}
