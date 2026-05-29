const std = @import("std");
const crypto_bins = @import("crypto_bins.zig");

pub const main = crypto_bins.Make(
    "md5sum",
    "compute MD5 checksums",
    std.crypto.hash.Md5,
);
