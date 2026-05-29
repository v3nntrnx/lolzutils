// https://pubs.opengroup.org/onlinepubs/9799919799/utilities/cat.html
// https://elixir.bootlin.com/busybox/1.37.0/source/coreutils/cat.c
// TODO: do gnu/coreutils stuff like using line_buf
const std = @import("std");
const Io = std.Io;

const core = @import("core");

const ShortOpt = enum {};

const LongOpt = enum {
    help,
    version,
};

// returns function to be used with main
pub fn Make(comptime name: []const u8, comptime description: []const u8, comptime HashClass: anytype) fn (std.process.Init) anyerror!u8 {
    return struct {
        pub fn main(init: std.process.Init) !u8 {
            var iter = init.minimal.args.iterate();
            _ = iter.next() orelse unreachable;

            var stdout_buf: [core.BUF_SIZE]u8 = undefined;
            var stdout_writer = Io.File.stdout().writer(init.io, &stdout_buf);
            defer stdout_writer.flush() catch @panic("Buffer flush error!");

            const stdout = &stdout_writer.interface;

            var parser: core.Parser(ShortOpt, LongOpt) = .init(init.minimal.args.iterate(), core.allocator);
            defer parser.deinit();

            while (try parser.nextPreserveArg()) |arg| {
                switch (arg) {
                    .Arg => {},
                    .Long => |l| switch (l.name) {
                        .help => return try help(stdout),
                        .version => return try version(stdout),
                    },
                    .Short => |s| while (try s.next()) |c| switch (c) {},
                }
            }

            for (parser.args.items) |arg| {
                if (std.mem.eql(u8, arg, "-")) {
                    unreachable;
                }

                const file = std.Io.Dir.cwd().openFile(init.io, arg, .{ .mode = .read_only }) catch |err| {
                    _ = switch (err) {
                        error.FileNotFound => core.sft_err("Unknown option '{s}' +No such file", .{arg}),
                        else => core.sft_err("Unknown option '{s}' +{s}", .{ arg, core.err_to_string(err) }),
                    };

                    continue;
                };
                defer file.close(init.io);

                var read_buf: [core.BUF_SIZE]u8 = undefined;
                var reader = file.reader(init.io, &read_buf);

                var hasher = HashClass.init(.{});
                var hash_buf: [core.BUF_SIZE]u8 = undefined;

                var discarding_buf: [core.BUF_SIZE]u8 = undefined;
                var discarding_writer = std.Io.Writer.Discarding.init(&discarding_buf);

                var hashed_writer = std.Io.Writer.hashed(&discarding_writer.writer, &hasher, &hash_buf);

                _ = try reader.interface.streamRemaining(&hashed_writer.writer);

                try hashed_writer.writer.flush();
                try discarding_writer.writer.flush();

                var final_hash: [HashClass.digest_length]u8 = undefined;
                hasher.final(&final_hash);

                try stdout.print("{x}  {s}\n", .{ &final_hash, arg });
            }

            return 0;
        }

        fn help(out: *Io.Writer) !u8 {
            try out.writeAll(
                \\Usage: 
            ++ name ++
                \\ <?Option(s)> <?File(s)>
                \\
            ++ description ++
                \\
                \\
                \\Option(s):
                \\  --help: display this help and exit
                \\  --version: output version information and exit
                \\
                \\
            ++ core.HELP_FOOTER ++ "\n");
            return 0;
        }

        fn version(out: *Io.Writer) !u8 {
            try out.writeAll(name ++ " v" ++ core.VERSION ++ "\n" ++ core.COPYRIGHT_LICENSE_FOOTER ++ "\n");
            return 0;
        }
    }.main;
}
