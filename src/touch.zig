const std = @import("std");
const Io = std.Io;

const core = @import("core");
const zeit = @import("zeit");

const C = @cImport({
    @cInclude("time.h");
});

// TODO: remove when zig will handle ENOENT properly in setTimestamps
pub const std_options = std.Options{
    .unexpected_error_tracing = false,
};

const Options = struct {
    change_access_time: ?bool = null, // -a
    no_create: ?bool = null, // -c, --no-create
    date: ?[]const u8 = null, // -d, --date=STRING
    no_dereference: ?bool = null, // -h, --no-dereference
    change_modification_time: ?bool = null, // -m
    reference_file: ?[]const u8 = null, // -r, --reference=FILE
    // -f is ignored. bsd compatibility only
    timestamp: ?[]const u8 = null, // -t
    time: ?[]const u8 = null, // --time=WORD [=acess|atime|use|modify|mtime]
};

const ShortOpt = enum { a, c, d, h, m, r, f, t };

const LongOpt = enum {
    @"no-create",
    date,
    @"no-dereference",
    reference,
    time,
    help,
    version,
};

const TimeBuf = struct {
    buf: [2]std.Io.File.SetTimestamp = [_]std.Io.File.SetTimestamp{ .unchanged, .unchanged },

    pub const atime = 0;
    pub const mtime = 1;

    pub const WhichTime = enum(usize) {
        atime = atime,
        mtime = mtime,
    };

    pub fn setFromNanoseconds(self: *TimeBuf, which: WhichTime, ns: anytype) void {
        self.buf[@intFromEnum(which)] = .{ .new = std.Io.Timestamp.fromNanoseconds(ns) };
    }
};

pub fn main(init: std.process.Init) !u8 {
    var stdout_buf: [core.BUF_SIZE]u8 = undefined;
    var stdout_writer = Io.File.stdout().writer(init.io, &stdout_buf);
    defer stdout_writer.flush() catch @panic("Buffer flush error!");

    const stdout = &stdout_writer.interface;

    var opts: Options = .{};

    var parser: core.Parser(ShortOpt, LongOpt) = .init(init.minimal.args.iterate(), core.allocator);
    defer parser.deinit();

    while (try parser.nextPreserveArg()) |arg| {
        switch (arg) {
            .Long => |l| switch (l.name) {
                .help => return try help(stdout),
                .version => return try version(stdout),
                .@"no-create" => {
                    if (l.arg) |_|
                        return core.sft_err("Option '--no-create' does not take an argument" ++ core.HELP_FOOTER_LN, .{});
                    opts.no_create = true;
                },
                .date => {
                    if (l.arg == null)
                        return core.sft_err("Option '--date' requires an argument" ++ core.HELP_FOOTER_LN, .{});
                    opts.date = l.arg;
                },
                .@"no-dereference" => {
                    if (l.arg) |_|
                        return core.sft_err("Option '--no-create' does not take an argument" ++ core.HELP_FOOTER_LN, .{});
                    opts.no_dereference = true;
                },
                .reference => {
                    if (l.arg == null)
                        return core.sft_err("Option '--reference' requires an argument" ++ core.HELP_FOOTER_LN, .{});
                    opts.reference_file = l.arg;
                },
                .time => {
                    if (l.arg == null)
                        return core.sft_err("Option '--time' requires an argument" ++ core.HELP_FOOTER_LN, .{});
                    opts.time = l.arg;
                },
            },
            .Short => |s| while (try s.next()) |so| {
                switch (so) {
                    .a => opts.change_access_time = true,
                    .c => opts.no_create = true,
                    .d => {
                        const next_arg = try parser.nextMustBe(.Arg) orelse
                            return core.sft_err("Option '-d' requires an argument" ++ core.HELP_FOOTER_LN, .{});

                        opts.date = next_arg.Arg;
                        try s.assertEnd();
                    },
                    .h => opts.no_dereference = true,
                    .m => opts.change_modification_time = true,
                    .r => {
                        const next_arg = try parser.nextMustBe(.Arg) orelse
                            return core.sft_err("Option '-r' requires an argument" ++ core.HELP_FOOTER_LN, .{});

                        opts.reference_file = next_arg.Arg;
                        try s.assertEnd();
                    },
                    .f => {}, // ignored for bsd compatibility
                    .t => {
                        const next_arg = try parser.nextMustBe(.Arg) orelse
                            return core.sft_err("Option '-t' requires an argument" ++ core.HELP_FOOTER_LN, .{});

                        opts.timestamp = next_arg.Arg;
                        try s.assertEnd();
                    },
                }
            },
            .Arg => {},
        }
    }

    if (@intFromBool(opts.time != null) +
        @intFromBool(opts.date != null) +
        @intFromBool(opts.timestamp != null) > 1)
        return core.s_err("Options '--date', '-t/' and '--timestamp' are mutually exclusive");

    // https://github.com/brgl/busybox/blob/master/coreutils/touch.c
    var timebuf: TimeBuf = .{};

    if (opts.reference_file) |ref_file| {
        const statbuf = try std.Io.Dir.cwd().statFile(init.io, ref_file, .{});

        if (statbuf.atime) |atime|
            timebuf.setFromNanoseconds(.atime, atime.toNanoseconds())
        else
            return core.sft_err("Reference file '{s}' does not have an access time", .{ref_file});

        timebuf.setFromNanoseconds(.mtime, statbuf.mtime.toNanoseconds());
    }

    if (opts.timestamp orelse opts.date orelse opts.time orelse null) |date_str| {
        // POSIX: YYYY-MM-DDThh:mm:SS[.frac][tz] or YYYY-MM-DDThh:mm:SS[,frac][tz]
        const time_info = try zeit.instant(init.io, .{
            .source = .{ .iso8601 = date_str },
        });

        timebuf.setFromNanoseconds(.atime, @as(i96, @intCast(time_info.timestamp)));
        timebuf.setFromNanoseconds(.mtime, @as(i96, @intCast(time_info.timestamp)));
    }

    // If only one of -a or -m is specified, change only that time. Otherwise, change both.
    if (@intFromBool(opts.change_access_time != null) +
        @intFromBool(opts.change_modification_time != null) == 1)
    {
        if (opts.change_access_time) |_|
            timebuf.buf[TimeBuf.mtime] = .unchanged
        else
            timebuf.buf[TimeBuf.atime] = .unchanged;
    }

    if (parser.args.items.len == 0)
        return core.s_err("No files specified");

    o: for (parser.args.items) |arg| {
        std.Io.Dir.cwd().setTimestamps(init.io, arg, .{
            .follow_symlinks = if (opts.no_dereference) |no_dereference| !no_dereference else false,
            .access_timestamp = timebuf.buf[TimeBuf.atime],
            .modify_timestamp = timebuf.buf[TimeBuf.mtime],
        }) catch |e| switch (e) {
            // Zig does not handle ENOENT for some reason.
            error.Unexpected => {
                if (opts.no_create) |no_create| if (no_create)
                    continue :o;

                // permissions = 0, which then later resolves to 0o666. which matches busybox's default permissions for creating files.
                const file = std.Io.Dir.cwd().createFile(init.io, arg, .{}) catch |err| {
                    _ = core.sft_err("Failed to create file '{s}': {s}", .{ arg, core.err_to_string(err) });
                    return 1;
                };
                file.close(init.io);
            },
            else => {
                _ = core.sft_err("Failed to set timestamp for file '{s}': {s}", .{ arg, core.err_to_string(e) });
                return 1;
            },
        };
    }

    return 0;
}

fn help(out: *Io.Writer) !u8 {
    try out.writeAll(
        \\Usage: touch <?Option>
        \\Create/Change the access and/or modification time of a file.
        \\
        \\Option(s):
        \\  --help: display this help and exit
        \\  --version: output version information and exit
        \\
        \\Report bugs to 
    ++ core.ISSUE_TRACKER ++ "\n");
    return 0;
}

fn version(out: *Io.Writer) !u8 {
    try out.writeAll(
        \\touch v
    ++ core.VERSION ++ "\n" ++ core.COPYRIGHT_LICENSE_FOOTER ++ "\n");
    return 0;
}
