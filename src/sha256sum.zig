const std = @import("std");
const crypto_bins = @import("crypto_bins.zig");

pub const main = crypto_bins.Make(
    "sha256sum",
    "compute SHA256 checksums",
    std.crypto.hash.sha2.Sha256,
);
