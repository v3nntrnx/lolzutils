const std = @import("std");

const core = @import("core");
const crypto_bin = @import("./common/crypto_bin.zig");

pub const main = crypto_bin.Make(
    Hasher,
    Hasher.digest_length,
    .{
        .name = "b2sum",
        .help = &help,
        .init_hash = &init_hash,
        .final_hash = &final_hash,
        .print_hash = &print_hash,
    },
);

const Hasher = std.crypto.hash.blake2.Blake2b512;

fn init_hash() Hasher {
    return Hasher.init(.{});
}

fn final_hash(hasher: *Hasher, buf: *[Hasher.digest_length]u8, _: usize) anyerror![]const u8 {
    hasher.final(buf);
    return buf;
}

fn print_hash(dest: *std.Io.Writer, buf: []const u8, _: usize) anyerror!void {
    try dest.print("{x} ", .{buf});
}

pub fn help(writer: *std.Io.Writer) !u8 {
    try writer.writeAll(
        \\Usage: b2sum <?Option(s)> <?File(s)>
        \\Print or check BLAKE2 checksums
        \\
        \\Option(s):
        \\  --help: display this help and exit
        \\  --version: output version information and exit
        \\
        \\
    ++ core.HELP_FOOTER ++ "\n");
    return 0;
}
