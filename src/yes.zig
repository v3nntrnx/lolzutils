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

    var repeat_str: std.ArrayList(u8) = .empty;
    defer repeat_str.deinit(core.allocator);

    var r_argc: usize = 0;

    while (iter.next()) |arg| : (r_argc += 1) {
        if (std.mem.eql(u8, arg, "--help")) {
            try help(stdout);
            return 0;
        }

        if (std.mem.eql(u8, arg, "--version")) {
            try version(stdout);
            return 0;
        }

        try repeat_str.appendSlice(core.allocator, arg);
        try repeat_str.append(core.allocator, ' ');
    }

    if (r_argc == 0) {
        while (true) {
            try stdout.writeAll("y\n");
            try stdout_writer.flush();
        }
    } else {
        repeat_str.items[repeat_str.items.len - 1] = '\n';

        while (true) {
            try stdout.writeAll(repeat_str.items);
            try stdout_writer.flush();
        }
    }

    return 0;
}

fn help(out: *Io.Writer) !void {
    try out.writeAll(
        \\Usage: yes <?Option> <?String>
        \\Repeatedly spam a string until killed. String defaults to 'y'.
        \\
        \\Option(s):
        \\  --help: display this help and exit
        \\  --version: output version information and exit
        \\
        \\Report bugs to 
    ++ core.ISSUE_TRACKER ++ "\n");
}

fn version(out: *Io.Writer) !void {
    try out.writeAll(
        \\yes v
    ++ core.VERSION ++ "\n" ++ core.COPYRIGHT_LICENSE_FOOTER ++ "\n");
}
