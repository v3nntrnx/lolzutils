#!/bin/sh
# Ported from coreutils: tests/touch/no-rights.sh
set -eu

tmpdir=$(mktemp -d)
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

if [ "$(id -u)" = "0" ]; then
  echo "Skipping test: running as root" >&2
  exit 77
fi

"$TOUCH" -d '2000-01-01 00:00' "$tmpdir/t1" || { echo "failed to create t1" >&2; exit 1; }
"$TOUCH" -d '2000-01-02 00:00' "$tmpdir/t2" || { echo "failed to create t2" >&2; exit 1; }

newest=$(ls -t "$tmpdir/t1" "$tmpdir/t2" | head -1)
if [ "$newest" != "$tmpdir/t2" ]; then
  echo "t2 should be newer than t1 initially" >&2
  exit 1
fi

chmod 0 "$tmpdir/t1"

"$TOUCH" -d '2000-01-03 00:00' -c "$tmpdir/t1" || { echo "touch -d -c on no-rights file failed" >&2; exit 1; }

newest=$(ls -t "$tmpdir/t1" "$tmpdir/t2" | head -1)
if [ "$newest" != "$tmpdir/t1" ]; then
  echo "t1 should be newer than t2 after touch" >&2
  exit 1
fi

"$TOUCH" -a --no-create "$tmpdir/t1" || { echo "touch -a --no-create on no-rights file failed" >&2; exit 1; }

echo "$(basename "$0"): Success"
