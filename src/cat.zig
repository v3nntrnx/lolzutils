// https://pubs.opengroup.org/onlinepubs/9799919799/utilities/cat.html
// https://elixir.bootlin.com/busybox/1.37.0/source/coreutils/cat.c
const std = @import("std");
const Io = std.Io;

const core = @import("core");

const Options = struct {
    enumerate_lines: bool = false,
};

const ShortOpt = enum {
    n,
    u,
};

const LongOpt = enum {
    help,
    version,
};

pub fn main(init: std.process.Init) !u8 {
    var iter = init.minimal.args.iterate();
    _ = iter.next() orelse unreachable;

    var stdout_buf: [core.BUF_SIZE]u8 = undefined;
    var stdout_writer = Io.File.stdout().writer(init.io, &stdout_buf);
    defer stdout_writer.flush() catch @panic("Buffer flush error!");

    const stdout = &stdout_writer.interface;

    var opts: Options = .{};

    var parser: core.Parser(ShortOpt, LongOpt) = .init(init.minimal.args.iterate(), core.allocator);
    defer parser.deinit();

    while (try parser.nextPreserveArg()) |arg| {
        switch (arg) {
            .Arg => {},
            .Long => |l| switch (l.name) {
                .help => return try help(stdout),
                .version => return try version(stdout),
            },
            .Short => |s| while (try s.next()) |c| switch (c) {
                .n => opts.enumerate_lines = true,
                .u => {},
            },
        }
    }

    var data: Data = .{};

    o: for (parser.args.items) |arg| {
        if (std.mem.eql(u8, arg, "-")) {
            try restream(init.io, Io.File.stdin(), stdout, &opts, &data);
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

        try restream(init.io, file, stdout, &opts, &data);
    }

    if (parser.args.items.len == 0)
        try restream(init.io, Io.File.stdin(), stdout, &opts, &data);

    return 0;
}

fn help(out: *Io.Writer) !u8 {
    try out.writeAll(
        \\Usage: cat <?Option(s)> <?File(s)>
        \\Concatenate files and print on the standard output. meow ^-^
        \\if no file is given, or if a file is given as '-', read from standard input.
        \\
        \\Option(s):
        \\  --help: display this help and exit
        \\  --version: output version information and exit
        \\  -u: (ignored, POSIX compliance)
        \\  -n: number all output lines
        \\
    ++ core.HELP_FOOTER ++ "\n");
    return 0;
}

fn version(out: *Io.Writer) !u8 {
    try out.writeAll(
        \\cat v
    ++ core.VERSION ++ "\n" ++ core.COPYRIGHT_LICENSE_FOOTER ++ "\n");
    return 0;
}

const Data = struct {
    l_padding: u32 = 6,
    line: u32 = 1,
};

// *const may be optional, but i think its a good optimization(?)
fn restream(io: Io, src: Io.File, dest: *Io.Writer, opts: *Options, data: *Data) !void {
    var src_buf: [core.BUF_SIZE]u8 = undefined;
    var src_reader = src.reader(io, &src_buf);
    var srcr = &src_reader.interface;

    if (opts.enumerate_lines) {
        var line_buf: [core.BUF_SIZE]u8 = undefined;

        while (true) {
            const l = srcr.readSliceShort(&line_buf) catch |err| core.sft_err("Failed to read file: {s}", .{core.err_to_string(err)});

            if (l == 0)
                return;

            const line_str = line_buf[0..l];

            var start_idx: usize = 0;
            while (std.mem.findScalarPos(u8, line_str, start_idx, '\n')) |nl| {
                var to_pad: i32 = @as(i32, @intCast(data.l_padding)) - @as(i32, @intCast(width_u32(data.line)));

                if (to_pad == -1) {
                    data.l_padding += 1;
                    to_pad += 1;
                }

                for (0..@intCast(to_pad)) |_|
                    try dest.writeByte(' ');
                try dest.print("{d}", .{data.line});
                try dest.writeByte('\t');

                defer start_idx = nl + 1;
                try dest.writeAll(line_str[start_idx .. nl + 1]);

                data.line += 1;
            }
        }

        unreachable;
    }

    _ = try srcr.streamRemaining(dest);
    return;
}

fn width_u32(n: u32) u32 {
    if (n < 10) return 1;
    if (n < 100) return 2;
    if (n < 1_000) return 3;
    if (n < 10_000) return 4;
    if (n < 100_000) return 5;
    if (n < 1_000_000) return 6;
    if (n < 10_000_000) return 7;
    if (n < 100_000_000) return 8;
    if (n < 1_000_000_000) return 9;
    return 10;
}
