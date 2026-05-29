#!/bin/sh
# Ported from coreutils: tests/touch/fifo.sh
set -eu

tmpdir=$(mktemp -d)
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

if ! mkfifo "$tmpdir/fifo" 2>/dev/null; then
  echo "Skipping test: mkfifo not supported" >&2
  exit 77
fi

"$TOUCH" "$tmpdir/fifo" || { echo "touch on fifo failed" >&2; exit 1; }

echo "$(basename "$0"): Success"
