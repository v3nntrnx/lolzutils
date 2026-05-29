#!/bin/sh
# Ported from coreutils: tests/touch/dangling-symlink.sh
set -eu

tmpdir=$(mktemp -d)
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

# Create a dangling symlink (touch-target does not exist yet)
ln -s "$tmpdir/touch-target" "$tmpdir/t-symlink"

# touch through the dangling symlink should create the target file
"$TOUCH" "$tmpdir/t-symlink" || { echo "touch through dangling symlink failed" >&2; exit 1; }

if [ -f "$tmpdir/touch-target" ]; then
  echo "$(basename "$0"): Success"
  exit 0
else
  echo "touch-target was not created through dangling symlink" >&2
  exit 1
fi
