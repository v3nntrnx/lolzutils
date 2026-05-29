#!/bin/sh
# Ported from coreutils: tests/touch/read-only.sh
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

> "$tmpdir/read-only"
chmod 444 "$tmpdir/read-only"

"$TOUCH" "$tmpdir/read-only" || { echo "touch on read-only file failed" >&2; exit 1; }

echo "$(basename "$0"): Success"