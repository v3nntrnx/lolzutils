#!/bin/sh
# Ported from coreutils: tests/touch/no-create-missing.sh
set -eu

tmpdir=$(mktemp -d)
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

"$TOUCH" -c "$tmpdir/no-file" || { echo "touch -c failed" >&2; exit 1; }
"$TOUCH" -cm "$tmpdir/no-file" || { echo "touch -cm failed" >&2; exit 1; }
"$TOUCH" -ca "$tmpdir/no-file" || { echo "touch -ca failed" >&2; exit 1; }

if env test -w /dev/stdout >/dev/null && env test ! -w /dev/stdout >&-; then
  "$TOUCH" -c - >&- 2>/dev/null || { echo "touch -c - failed" >&2; exit 1; }
  "$TOUCH" -cm - >&- 2>/dev/null || { echo "touch -cm - failed" >&2; exit 1; }
  "$TOUCH" -ca - >&- 2>/dev/null || { echo "touch -ca - failed" >&2; exit 1; }
fi

echo "$(basename "$0"): Success"
