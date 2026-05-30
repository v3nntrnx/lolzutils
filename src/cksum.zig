const std = @import("std");

const core = @import("core");
const crypto_bin = @import("crypto_bin.zig");

pub const digest_length = 12;

pub const main = crypto_bin.Make(
    Hasher,
    digest_length, // 4 u8 = 32 bits
    .{
        .name = "cksum",
        .help = &help,
        .init_hash = &init_hash,
        .final_hash = &final_hash,
        .print_hash = &print_hash,
    },
);

const Hasher = std.hash.crc.Crc32Cksum;

fn init_hash() Hasher {
    return Hasher.init();
}

fn final_hash(hasher: *Hasher, buf: *[digest_length]u8, bytes_written: usize) anyerror![]const u8 {
    var len = bytes_written;

    while (len != 0) {
        hasher.update(&[_]u8{@truncate(len & 0xFF)});
        len >>= 8;
    }

    return try std.fmt.bufPrint(buf, "{d}", .{hasher.final()});
}

fn print_hash(dest: *std.Io.Writer, buf: []const u8, bytes_written: usize) anyerror!void {
    try dest.print("{s} {d}  ", .{ buf, bytes_written });
}

pub fn help(writer: *std.Io.Writer) !u8 {
    try writer.writeAll(
        \\Usage: cksum <?Option(s)> <?File(s)>
        \\Print or check checksums, defaulting to CRC32
        \\
        \\Option(s):
        \\  --help: display this help and exit
        \\  --version: output version information and exit
        \\
        \\
    ++ core.HELP_FOOTER ++ "\n");
    return 0;
}
