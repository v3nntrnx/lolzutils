const std = @import("std");
const Io = std.Io;

const core = @import("core");
const C = @cImport({
    @cInclude("sys/types.h");
    @cInclude("pwd.h");
    @cInclude("unistd.h");
});

pub fn main(init: std.process.Init) !u8 {
    var iter = init.minimal.args.iterate();
    _ = iter.next() orelse unreachable;

    var stdout_buf: [core.BUF_SIZE]u8 = undefined;

    var stdout_writer = Io.File.stdout().writer(init.io, &stdout_buf);
    defer stdout_writer.flush() catch @panic("Buffer flush error!");

    var stdout = &stdout_writer.interface;

    while (iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help")) {
            try help(stdout);
            return 0;
        }

        if (std.mem.eql(u8, arg, "--version")) {
            try version(stdout);
            return 0;
        }

        _ = core.sft_err("Unknown option '{s}'" ++ core.HELP_FOOTER_LN, .{arg});
        return 1;
    }

    const euid: std.posix.uid_t = switch (core.os) {
        .linux => std.os.linux.geteuid(),
        else => @intCast(C.geteuid()),
    };

    const pwent = C.getpwuid(euid);

    if (pwent == null) {
        _ = core.sft_err("No user found for euid: {d}", .{euid});
        return 1;
    }

    try stdout.writeAll(std.mem.span(pwent.*.pw_name));
    try stdout.writeByte('\n');

    return 0;
}

fn help(out: *Io.Writer) !void {
    try out.writeAll(
        \\Usage: whoami <?Option>
        \\Print the user name associated with the current effective user ID.
        \\
        \\Option(s):
        \\  --help: display this help and exit
        \\  --version: output version information and exit
        \\
        \\
    ++ core.HELP_FOOTER ++ "\n");
}

fn version(out: *Io.Writer) !void {
    try out.writeAll(
        \\whoami v
    ++ core.VERSION ++ "\n" ++ core.COPYRIGHT_LICENSE_FOOTER ++ "\n");
}
