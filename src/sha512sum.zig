const std = @import("std");
const crypto_bins = @import("crypto_bins.zig");

pub const main = crypto_bins.Make(
    "sha512sum",
    "compute SHA512 checksums",
    std.crypto.hash.sha2.Sha512,
);
