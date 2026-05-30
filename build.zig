const std = @import("std");

const Globals = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    core_mod: *std.Build.Module,
    zeit: *std.Build.Module,
};

pub fn makeProgram(
    b: *std.Build,
    g: Globals,
    comptime name: []const u8,
    libc: bool,
) !void {
    const exe = b.addExecutable(.{
        .name = name,
        .use_lld = libc,
        .use_llvm = libc,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/" ++ name ++ ".zig"),
            .target = g.target,
            .optimize = g.optimize,
            .imports = &.{
                .{ .name = "core", .module = g.core_mod },
                .{ .name = "zeit", .module = g.zeit },
            },
        }),
    });
    exe.is_linking_libc = libc;
    b.installArtifact(exe);

    const run_step = b.step("run-" ++ name, "Run the app // " ++ name);
    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());
    run_step.dependOn(&run_cmd.step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_mod = b.addModule("core", .{
        .root_source_file = b.path("src/core.zig"),
        .target = target,
        .optimize = optimize,
    });

    const zeit_dep = b.dependency("zeit", .{});
    const zeit = zeit_dep.module("zeit");

    const g = Globals{
        .target = target,
        .optimize = optimize,
        .core_mod = core_mod,
        .zeit = zeit,
    };

    try makeProgram(b, g, "cat", false);
    try makeProgram(b, g, "yes", false);
    try makeProgram(b, g, "whoami", true);
    try makeProgram(b, g, "touch", false);
    try makeProgram(b, g, "b2sum", false);
    try makeProgram(b, g, "cksum", false);
    try makeProgram(b, g, "md5sum", false);
    try makeProgram(b, g, "sha1sum", false);
    try makeProgram(b, g, "sha256sum", false);
    try makeProgram(b, g, "sha512sum", false);
}
