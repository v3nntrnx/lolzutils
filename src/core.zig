const std = @import("std");
const builtin = @import("builtin");

pub const os = builtin.os.tag;
pub const allocator = if (builtin.mode == .Debug) std.heap.page_allocator else std.heap.smp_allocator;

pub const VERSION = "0.1";
pub const ISSUE_TRACKER = "codeberg.org/v3nntrnx/lolzutils";
pub const HELP_FOOTER_LN = "Use --help for more information\n";
pub const COPYRIGHT_LICENSE_FOOTER =
    \\Copyright (C) 2026 v3nntrnx
;
pub const BUF_SIZE = 4096;

pub fn s_err(comptime f: []const u8) u8 {
    std.log.err(f, .{});
    return 1;
}

pub fn sf_err(comptime f: []const u8, err: anyerror) u8 {
    std.log.err(f ++ "{s}", .{err_to_string(err)});
    return 1;
}

pub fn sft_err(comptime f: []const u8, args: anytype) u8 {
    std.log.err(f, args);
    return 1;
}

pub fn err_to_string(err: anyerror) []const u8 {
    if (err == error.FileNotFound)
        return "No such file or directory";

    if (err == error.IsDir)
        return "Is a directory";

    if (err == error.AccessDenied)
        return "Access denied";

    return @errorName(err);
}

pub fn Parser(comptime ShortOpt: type, comptime LongOption: type) type {
    return struct {
        const ShortOptIterator = struct {
            arg: []const u8,
            index: usize,

            pub fn next(self: *ShortOptIterator) !?ShortOpt {
                if (self.index >= self.arg.len)
                    return null;

                const c = self.advance();
                return std.meta.stringToEnum(ShortOpt, &[_]u8{c}) orelse return error.InvalidShortOption;
            }

            /// You can do break after calling this function to avoid unnecessary iterations, but it is not required.
            pub fn assertEnd(self: *ShortOptIterator) !void {
                if (self.index != self.arg.len)
                    return error.TrailingCharactersInShortOption;
            }

            pub inline fn peek(self: *ShortOptIterator) u8 {
                return self.arg[self.index];
            }

            pub inline fn peekBack(self: *ShortOptIterator) u8 {
                return self.arg[self.index -| 1];
            }

            inline fn advance(self: *ShortOptIterator) u8 {
                defer self.index += 1;
                return self.peek();
            }
        };

        const IterState = switch (os) {
            .windows => std.process.Args.Iterator.Windows,
            .wasi => if (builtin.link_libc) std.process.Args.Iterator.Posix else std.process.Args.Iterator.Wasi,
            else => std.process.Args.Iterator.Posix,
        };

        iter: std.process.Args.Iterator,
        saved: ?IterState = null,
        args: std.ArrayList([]const u8) = .empty,
        indexed: usize = 0,
        gpa: std.mem.Allocator,
        short_opt_iter: ShortOptIterator = undefined,

        pub fn init(args: std.process.Args.Iterator, gpa: std.mem.Allocator) @This() {
            return .{ .iter = args, .gpa = gpa };
        }

        pub fn deinit(self: *@This()) void {
            self.args.deinit(self.gpa);
        }

        pub fn save(self: *@This()) void {
            self.saved = self.iter.inner;
        }

        pub fn restore(self: *@This()) void {
            self.iter.inner = self.saved orelse unreachable;
        }

        pub fn next(self: *@This()) !?ParsedArg {
            defer self.indexed += 1;

            if (self.indexed == 0)
                _ = self.iter.next() orelse unreachable;

            const arg = self.iter.next() orelse return null;

            if (std.mem.startsWith(u8, arg, "--")) {
                if (arg.len > 2)
                    return ParsedArg{
                        .Long = try self.parseLongOption(arg),
                    };

                // POSIX defines -- as the end of options.
                while (self.iter.next()) |next_arg| {
                    try self.preserve(next_arg);
                }

                return null;
            }

            if (std.mem.startsWith(u8, arg, "-") and arg.len > 1) {
                self.short_opt_iter = ShortOptIterator{ .arg = arg[1..], .index = 0 };

                return ParsedArg{
                    .Short = &self.short_opt_iter,
                };
            }

            return ParsedArg{
                .Arg = arg,
            };
        }

        pub fn nextPreserveArg(self: *@This()) !?ParsedArg {
            const nx = try self.next() orelse return null;

            if (nx == .Arg)
                try self.preserve(nx.Arg);

            return nx;
        }

        pub fn preserve(self: *@This(), arg: []const u8) !void {
            try self.args.append(self.gpa, arg);
        }

        /// Unpreseved!!! e.g. If the next argument is an option, it will not be saved in self.args.
        pub fn nextMustBe(self: *@This(), tag: std.meta.Tag(ParsedArg)) !?ParsedArg {
            const nx = try self.next() orelse return null;

            if (std.meta.activeTag(nx) == tag)
                return nx;

            return null;
        }

        pub fn parseLongOption(self: *@This(), arg: []const u8) !ParsedLongOption {
            if (arg.len < 3)
                return error.InvalidLongOption;

            const raw_long_opt = arg[2..];
            const eq_index = std.mem.indexOfScalar(u8, raw_long_opt, '=');
            const long_opt = std.meta.stringToEnum(LongOption, if (eq_index) |i| raw_long_opt[0..i] else raw_long_opt) orelse
                return error.InvalidLongOption;

            if (eq_index) |i| {
                if (i >= raw_long_opt.len - 1)
                    return error.InvalidLongOption;

                var lookup_quote: u8 = '\'';

                e: while (true) {
                    if (raw_long_opt[i + 1] == lookup_quote) {
                        const begin_first_quote_pos = i + 1;
                        const maybe_end_first_quote_pos = std.mem.lastIndexOfScalar(u8, raw_long_opt[begin_first_quote_pos + 1 ..], '\'');

                        if (maybe_end_first_quote_pos) |end_first_quote_pos| o: {
                            if (end_first_quote_pos == begin_first_quote_pos)
                                break :o;

                            return ParsedLongOption{
                                .name = long_opt,
                                .arg = raw_long_opt[begin_first_quote_pos + 1 .. end_first_quote_pos],
                                .passed_by_eq = true,
                            };
                        }

                        var parsed_long_opt_arg: std.ArrayList(u8) = .empty;
                        defer parsed_long_opt_arg.deinit(self.gpa);

                        try parsed_long_opt_arg.appendSlice(self.gpa, raw_long_opt[begin_first_quote_pos + 1 ..]);

                        i: {
                            while (self.iter.next()) |next_arg| {
                                if (std.mem.indexOfScalar(
                                    u8,
                                    next_arg,
                                    lookup_quote,
                                )) |closing_quote_pos| {
                                    if (closing_quote_pos != next_arg.len - 1) {
                                        return error.ClosingQuoteMustBeLastCharacter;
                                    }

                                    const str = next_arg[0..closing_quote_pos -| 1];

                                    try parsed_long_opt_arg.appendSlice(self.gpa, str);
                                    break :i;
                                }

                                try parsed_long_opt_arg.appendSlice(self.gpa, next_arg);
                                try parsed_long_opt_arg.appendSlice(self.gpa, " ");
                            }

                            return error.ClosingQuoteNotFound;
                        }

                        return ParsedLongOption{
                            .name = long_opt,
                            .arg = try parsed_long_opt_arg.toOwnedSlice(self.gpa),
                            .passed_by_eq = true,
                        };
                    }

                    if (lookup_quote == '\'') {
                        lookup_quote = '"';
                        continue :e;
                    }

                    break :e;
                }

                return ParsedLongOption{
                    .name = long_opt,
                    .arg = raw_long_opt[i + 1 ..],
                    .passed_by_eq = true,
                };
            }

            self.save();

            if (self.iter.next()) |next_arg| o: {
                if (std.mem.startsWith(u8, next_arg, "-")) {
                    self.restore();
                    break :o;
                }

                return ParsedLongOption{
                    .name = long_opt,
                    .arg = next_arg,
                };
            }

            return ParsedLongOption{
                .name = long_opt,
                .arg = null,
            };
        }

        const ParsedArg = union(enum) {
            Short: *ShortOptIterator,
            Long: ParsedLongOption,
            Arg: []const u8,
        };

        // pub const ParsedShortOption = struct {
        //     name: ShortOpt,
        // };

        pub const ParsedLongOption = struct {
            name: LongOption,
            arg: ?[]const u8,
            passed_by_eq: bool = false,
        };
    };
}
