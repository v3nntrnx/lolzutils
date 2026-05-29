const std = @import("std");
const crypto_bins = @import("crypto_bins.zig");

pub const main = crypto_bins.Make(
    "sha1sum",
    "compute SHA1 checksums",
    std.crypto.hash.Sha1,
);
