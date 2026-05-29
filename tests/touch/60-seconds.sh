#!/bin/sh
# Ported from coreutils: tests/touch/60-seconds.sh
set -eu
tmpdir=$(mktemp -d)

cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

printf "60.000000000\n" > $tmpdir/exp

TZ=UTC0 "$TOUCH" -t 197001010000.60 $tmpdir/f || exit 1

stat --format='%.9Y' $tmpdir/f > $tmpdir/out || exit 1

if cmp -s $tmpdir/out $tmpdir/exp; then
  echo "$(basename "$0"): Success"
  exit 0
else
  echo "Mismatch between expected and actual output" >&2
  echo "Expected:" >&2
  cat $tmpdir/exp >&2
  echo "Got:" >&2
  cat $tmpdir/out >&2
  exit 1
fi

unreachable