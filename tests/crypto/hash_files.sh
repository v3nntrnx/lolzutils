#!/bin/sh
set -eu
tmpdir=$(mktemp -d)

cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

TEST_FILE=$(mktemp "$tmpdir/test_file.XXXXXX")
dd if=/dev/urandom of="$TEST_FILE" bs=1M count=10 status=none 2>/dev/null

DIR_A="$ZIG_OUT/bin"
DIR_B="/usr/bin"

failures=0
for script_path in "$DIR_A"/*sum; do
    [[ -e "$script_path" ]] || continue

    binary_name=$(basename "$script_path")
    target_path="$DIR_B/$binary_name"

    hash_a=$("$script_path" "$TEST_FILE" | awk '{print $1}')
    hash_b=$("$target_path" "$TEST_FILE" | awk '{print $1}')

    if [[ "$hash_a" == "$hash_b" ]]; then
        echo "[MATCH] $binary_name: Both paths output '$hash_a'"
    else
        echo "[FAIL]  $binary_name: Output mismatch!" >&2
        echo "        $script_path: $hash_a" >&2
        echo "        $target_path: $hash_b" >&2
        failures=$((failures + 1))
    fi
done

if [ "$failures" -gt 0 ]; then
    exit 1
fi

echo "$(basename "$0"): Success"
exit 0