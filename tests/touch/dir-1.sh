#!/bin/sh
# Ported from coreutils: tests/touch/dir-1.sh
set -eu

tmpdir=$(mktemp -d)
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

"$TOUCH" "$tmpdir" || { echo "touch on a directory failed" >&2; exit 1; }

echo "$(basename "$0"): Success"
