const std = @import("std");
const crypto_bins = @import("crypto_bins.zig");

pub const main = crypto_bins.Make(
    "b2sum",
    "compute BLAKE2 checksums",
    std.crypto.hash.blake2.Blake2b512,
);
