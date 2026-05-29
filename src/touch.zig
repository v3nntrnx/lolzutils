// https://pubs.opengroup.org/onlinepubs/9799919799/utilities/touch.html
// https://elixir.bootlin.com/busybox/1.37.0/source/coreutils/touch.c
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
    time: ?[]const u8 = null, // --time=WORD [=access|atime|use|modify|mtime]
};

const TimeWORD = enum(u8) {
    access = 0,
    atime = 1,
    use = 2,
    modify = 3,
    mtime = 4,

    const WhereModStarts: u8 = 3;
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
    buf: [2]std.Io.File.SetTimestamp = [_]std.Io.File.SetTimestamp{ .now, .now },

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
                    if (l.arg) |la| {
                        if (l.passed_by_eq)
                            return core.sft_err("Option '--no-create' does not take an argument", .{});

                        try parser.preserve(la);
                    }

                    opts.no_create = true;
                },
                .date => {
                    if (l.arg == null)
                        return core.sft_err("Option '--date' requires an argument", .{});

                    opts.date = l.arg;
                },
                .@"no-dereference" => {
                    if (l.arg) |la| {
                        if (l.passed_by_eq)
                            return core.sft_err("Option '--no-dereference' does not take an argument", .{});

                        try parser.preserve(la);
                    }

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
            .Short => |s| while (s.next() catch |e| switch (e) {
                error.InvalidShortOption => return core.sft_err("Invalid option '{c}'", .{s.peekBack()}),
                //    else => return core.sft_err("Failed to parse options: {s}", .{core.err_to_string(e)}),
            }) |so| {
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
        const statbuf = try std.Io.Dir.cwd().statFile(init.io, ref_file, .{
            .follow_symlinks = if (opts.no_dereference) |_| false else true,
        });

        if (statbuf.atime) |atime|
            timebuf.setFromNanoseconds(.atime, atime.toNanoseconds())
        else
            return core.sft_err("Reference file '{s}' does not have an access time", .{ref_file});

        timebuf.setFromNanoseconds(.mtime, statbuf.mtime.toNanoseconds());
    }

    if (opts.timestamp) |timestamp_str| {
        // POSIX: [[CC]YY]MMDDhhmm[.SS]

        // The resulting time shall be affected by the value of the TZ environment variable.
        const env_config: zeit.EnvConfig = .{
            .tz = init.environ_map.get("TZ"),
        };

        var local_tz = (try zeit.local(init.gpa, init.io, env_config));
        defer local_tz.deinit();

        var tz_instant = try zeit.instant(init.io, .{
            .source = .now,
            .timezone = &local_tz,
        });

        var time: zeit.Time = .{
            .year = tz_instant.time().year,
        };

        // Parse from the end, since the year/century (a.k CC and YY) are optional
        // [.SS] where SS is The second of the minute, between 00 and 60. (60 for leap year)
        const maybe_frac = std.mem.indexOfScalar(u8, timestamp_str, '.');

        if (maybe_frac) |dot_index| {
            const frac_str = timestamp_str[dot_index + 1 ..];

            if (frac_str.len > 9)
                return core.s_err("Invalid timestamp: too many digits in fractional seconds");

            // DEV NOTE: AFAIK zeit does handle leap seconds.
            // We handle TZ environment before.
            time.second = std.fmt.parseInt(u6, frac_str, 10) catch |e|
                return core.sf_err("Invalid timestamp: non-digit character found in fractional seconds ", e);
        }

        const main_time_str = if (maybe_frac) |dot_index|
            timestamp_str[0..dot_index]
        else
            timestamp_str;

        var reverse_iter = std.mem.reverseIterator(main_time_str);
        const Stage = enum(u8) { minute = 0, hour, day, month, year };
        var stage: Stage = .minute;

        o: while (true) {
            const c1 = reverse_iter.next() orelse if (stage == .month) break else return core.s_err("Invalid timestamp: not enough fields");
            const c2 = reverse_iter.next() orelse return core.s_err("Invalid timestamp: not enough fields");

            if (!std.ascii.isDigit(c1) or !std.ascii.isDigit(c2))
                return core.s_err("Invalid timestamp: non-digit character found in timestamp");

            const field_value: u8 = (c2 - '0') * 10 + (c1 - '0'); // you *could* store this as u7

            stage = switch (stage) {
                // mm where mm is The minute of the hour, between 00 and 60.
                .minute => v: {
                    if (field_value > 60)
                        return core.s_err("Invalid timestamp: minute value out of range");

                    time.minute = @intCast(field_value);
                    break :v .hour;
                },
                // hh where hh is The hour of the day, between 00 and 23.
                .hour => v: {
                    if (field_value > 23)
                        return core.s_err("Invalid timestamp: hour value out of range");

                    time.hour = @intCast(field_value);
                    break :v .day;
                },
                // DD where DD is The day of the month, between 01 and 31.
                .day => v: {
                    if (field_value == 0 or field_value > 31)
                        return core.s_err("Invalid timestamp: day value out of range");

                    time.day = @intCast(field_value);
                    break :v .month;
                },
                // MM where MM is The month of the year, between 01 and 12.
                .month => v: {
                    if (field_value == 0 or field_value > 12)
                        return core.s_err("Invalid timestamp: month value out of range");
                    time.month = @enumFromInt(field_value);
                    break :v .year;
                },
                // YY where YY is The last two digits of the year
                .year => {
                    // try to parse a CC field. if it fails, assume CC is 19 or 20 depending on the value of YY
                    // YY in the range 69-99 corresponds to 1969-1999, and YY in the range 00-68 corresponds to 2000-2068.
                    // NOTE: this is expected to be changed.
                    const maybe_cc_c1 = reverse_iter.next();
                    const maybe_cc_c2 =
                        if (maybe_cc_c1) |_|
                            reverse_iter.next() orelse
                                return core.s_err("Invalid timestamp: not enough fields")
                        else
                            null;

                    if (reverse_iter.next()) |_|
                        return core.s_err("Invalid timestamp: too many fields");

                    // if CC given
                    if (maybe_cc_c2) |cc_c2| {
                        const cc_field_value: u8 = (cc_c2 - '0') * 10 + (maybe_cc_c1.? - '0');

                        const year: i32 = (@as(i32, @intCast(cc_field_value)) * 100) + field_value;
                        time.year = year;
                    } else {
                        const year: i32 = if (field_value <= 68) 2000 + @as(i32, @intCast(field_value)) else 1900 + @as(i32, @intCast(field_value));
                        time.year = year;
                    }

                    break :o;
                },
            };
        }

        const time_info = time.instant();
        timebuf.setFromNanoseconds(.atime, @as(i96, @intCast(time_info.timestamp)));
        timebuf.setFromNanoseconds(.mtime, @as(i96, @intCast(time_info.timestamp)));
    }

    if (opts.date) |_date_str| {
        var date_str = _date_str;
        defer if (date_str.len != _date_str.len) init.gpa.free(date_str);

        // a hack to support [+/-]hh:mm with trailing space before +
        // e.g 2004-01-16 12:00 +0000 would remove space before +
        if (std.mem.find(u8, date_str, " +")) |trailing_plus| {
            const dt = init.gpa.dupe(u8, date_str[0 .. date_str.len - 1]) catch @panic("OOM");
            std.mem.copyForwards(
                u8,
                dt[trailing_plus..],
                date_str[trailing_plus + 1 ..],
            );
            date_str = dt;
        }

        const time_info = zeit.instant(init.io, .{
            .source = .{ .iso8601 = date_str },
        }) catch |err| return core.sft_err("Could not parse date '{s}': {s}", .{ date_str, core.err_to_string(err) });

        timebuf.setFromNanoseconds(.atime, @as(i96, @intCast(time_info.timestamp)));
        timebuf.setFromNanoseconds(.mtime, @as(i96, @intCast(time_info.timestamp)));
    }

    if (opts.time) |time_str| {
        const time_word = std.meta.stringToEnum(TimeWORD, time_str) orelse
            return core.sft_err("Invalid time word: '{s}'", .{time_str});

        // neat hack? isn't it? access turns to modify and modify turns to access. how cool is that? love +%
        timebuf.buf[@as(u1, @intFromBool(@intFromEnum(time_word) > TimeWORD.WhereModStarts) +% 1)] = .unchanged;
    }

    // If only one of -a or -m is specified, change only that time. Otherwise, change both.
    if (@intFromBool(opts.change_access_time != null) +
        @intFromBool(opts.change_modification_time != null) == 1)
    {
        // im not hacking here.
        if (opts.change_access_time) |_|
            timebuf.buf[TimeBuf.mtime] = .unchanged
        else
            timebuf.buf[TimeBuf.atime] = .unchanged;
    }

    if (parser.args.items.len == 0)
        return core.s_err("No files specified");

    o: for (parser.args.items) |arg| {
        // Zig does not handle ENOENT for some reason. that's why we check if the file exists.
        // This is *not really* POSIX behaviour but fixes dangling symlink test.
        // This may also not be *fast*.
        _ = std.Io.Dir.cwd().statFile(init.io, arg, .{
            .follow_symlinks = if (opts.no_dereference) |_| false else true,
        }) catch |e| switch (e) {
            error.FileNotFound => {
                if (opts.no_create) |no_create| if (no_create)
                    continue :o;

                const file = std.Io.Dir.cwd().createFile(init.io, arg, .{}) catch |err| {
                    _ = core.sft_err("Failed to create file '{s}': {s}", .{ arg, core.err_to_string(err) });
                    return 1;
                };
                defer file.close(init.io);

                try file.setTimestamps(init.io, .{
                    .access_timestamp = timebuf.buf[TimeBuf.atime],
                    .modify_timestamp = timebuf.buf[TimeBuf.mtime],
                });
                continue :o;
            },
            else => {
                _ = core.sft_err("Failed to stat file before creating '{s}': {s}", .{ arg, core.err_to_string(e) });
                return 1;
            },
        };

        std.Io.Dir.cwd().setTimestamps(init.io, arg, .{
            .follow_symlinks = if (opts.no_dereference) |_| false else true,
            .access_timestamp = timebuf.buf[TimeBuf.atime],
            .modify_timestamp = timebuf.buf[TimeBuf.mtime],
        }) catch |e| {
            _ = core.sft_err("Failed to set timestamp for file '{s}': {s}", .{ arg, core.err_to_string(e) });
            return 1;
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
