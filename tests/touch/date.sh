#!/bin/sh
# Ported from coreutils: tests/touch/relative.sh
set -eu

tmpdir=$(mktemp -d)
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

# Space before + is hacky.
TZ=UTC0 "$TOUCH" --date='2004-01-16 12:00 +0000' "$tmpdir/f" || { echo "failed to create f" >&2; exit 1; }

actual=$(TZ=UTC0 stat --format=%y "$tmpdir/f" | cut -d' ' -f1)
expected="2004-01-16"

if [ "$actual" = "$expected" ]; then
  echo "$(basename "$0"): Success"
  exit 0
else
  echo "Mismatch between expected and actual date" >&2
  echo "Expected: $expected" >&2
  echo "Got:      $actual" >&2
  exit 1
fi
