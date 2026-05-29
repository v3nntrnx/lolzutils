#!/bin/sh
# Ported from coreutils: tests/touch/fail-diag.sh
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

file=/no-such-dir/file

"$TOUCH" "$file" > "$tmpdir/out" 2>&1 && { echo "touch should have failed" >&2; exit 1; }

printf "'%s': No such file or directory\n" "$file" > "$tmpdir/exp"
tail -c "$(wc -c < "$tmpdir/exp")" "$tmpdir/out" > "$tmpdir/out.truncated"

# NOTE: this is changed so this checks for *any* failure message.
# not just GNU/coreutils specific.

if cmp -s "$tmpdir/out.truncated" "$tmpdir/exp"; then
  echo "$(basename "$0"): Success"
  exit 0
else
  echo "Mismatch between expected and actual output" >&2
  echo "Expected:" >&2
  cat "$tmpdir/exp" >&2
  echo "Got:" >&2
  cat "$tmpdir/out" >&2
  exit 1
fi
