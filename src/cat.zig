const std = @import("std");
const Io = std.Io;

const core = @import("core");

pub fn main(init: std.process.Init) !u8 {
    var iter = init.minimal.args.iterate();
    _ = iter.next() orelse unreachable;

    var stdout_buf: [core.BUF_SIZE]u8 = undefined;
    var stdout_writer = Io.File.stdout().writer(init.io, &stdout_buf);
    defer stdout_writer.flush() catch @panic("Buffer flush error!");

    const stdout = &stdout_writer.interface;

    var r_argc: usize = 0;

    o: while (iter.next()) |arg| : (r_argc += 1) {
        if (std.mem.eql(u8, arg, "--help")) {
            try help(stdout);
            return 0;
        }

        if (std.mem.eql(u8, arg, "--version")) {
            try version(stdout);
            return 0;
        }

        if (std.mem.eql(u8, arg, "-")) {
            try restream(init.io, Io.File.stdin(), stdout);
            continue :o;
        }

        const file = std.Io.Dir.cwd().openFile(init.io, arg, .{ .mode = .read_only }) catch |err| {
            _ = switch (err) {
                error.FileNotFound => core.sft_err("Unknown option '{s}' +No such file", .{arg}),
                else => core.sft_err("Unknown option '{s}' +{s}", .{ arg, core.err_to_string(err) }),
            };

            continue :o;
        };
        defer file.close(init.io);

        try restream(init.io, file, stdout);
    }

    if (r_argc == 0)
        try restream(init.io, Io.File.stdin(), stdout);

    return 0;
}

fn help(out: *Io.Writer) !void {
    try out.writeAll(
        \\Usage: cat <?Option(s)> <?File(s)>
        \\Concatenate files and print on the standard output. meow ^-^
        \\if no file is given, or if a file is given as '-', read from standard input.
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
        \\cat v
    ++ core.VERSION ++ "\n" ++ core.COPYRIGHT_LICENSE_FOOTER ++ "\n");
}

fn restream(io: Io, src: Io.File, dest: *Io.Writer) !void {
    var stdin_buf: [core.BUF_SIZE]u8 = undefined;
    var stdin_reader = src.reader(io, &stdin_buf);
    _ = try (&stdin_reader.interface).streamRemaining(dest);
}
