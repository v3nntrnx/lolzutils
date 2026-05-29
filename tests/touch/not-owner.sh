#!/bin/sh
# Ported from coreutils: tests/touch/not-owner.sh
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

if [ -w / ]; then
  echo "Skipping test: have write access to /" >&2
  exit 77
fi

if [ -O / ] || [ -G / ]; then
  echo "Skipping test: you own /" >&2
  exit 77
fi

"$TOUCH" / > "$tmpdir/out" 2>&1 && { echo "touch / should have failed" >&2; exit 1; }

match=0
for msg in "Permission denied" "Operation not permitted" "Read-only file system" "Access denied"; do
  if grep -qF "$msg" "$tmpdir/out"; then
    match=1
    break
  fi
done

if [ "$match" != "1" ]; then
  echo "Unexpected output from touch /:" >&2
  cat "$tmpdir/out" >&2
  exit 1
fi

echo "$(basename "$0"): Success"
