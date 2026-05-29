#!/bin/sh
# Ported from coreutils: tests/touch/empty-file.sh
set -eu

tmpdir=$(mktemp -d)
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

# Create three empty files
> "$tmpdir/a"
> "$tmpdir/b"
> "$tmpdir/c"

sleep 2

# Touch a, it should now be newer than b
"$TOUCH" "$tmpdir/a" || { echo "touch failed on a" >&2; exit 1; }

newest=$(ls -t "$tmpdir/a" "$tmpdir/b" | head -1)
if [ "$newest" != "$tmpdir/a" ]; then
  echo "Expected a to be newer than b after touch" >&2
  exit 1
fi

sleep 2

# Touch b, it should now be newer than a
"$TOUCH" "$tmpdir/b" || { echo "touch failed on b" >&2; exit 1; }

newest=$(ls -t "$tmpdir/a" "$tmpdir/b" | head -1)
if [ "$newest" != "$tmpdir/b" ]; then
  echo "Expected b to be newer than a after touch" >&2
  exit 1
fi

# This is not supported per POSIX, and works only in GNU coreutils
# Busybox also does not support this

# Touch c via stdin fd (touch -)
# if "$TOUCH" - 1< "$tmpdir/c" 2>/dev/null; then
#   newest=$(ls -t "$tmpdir/a" "$tmpdir/c" | head -1)
#   if [ "$newest" != "$tmpdir/c" ]; then
#     echo "Expected c to be newer than a after touch via stdin fd" >&2
#     exit 1
#   fi
# fi

echo "$(basename "$0"): Success"
