#!/bin/sh
# Ported from coreutils: tests/touch/now-owned-by-other.sh
set -eu

# TODO: Pass this from test runner
NON_ROOT_GID=1000
NON_ROOT_USERNAME=$(getent group 1000 | cut -d: -f1)

tmpdir=$(mktemp -d)
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

if [ "$(id -u)" != "0" ]; then
  echo "Skipping test: must be run as root" >&2
  exit 77
fi

# Create a file owned by root, writable by the non-root group
> "$tmpdir/root-owned"
chgrp "+$NON_ROOT_GID" "$tmpdir" "$tmpdir/root-owned" || { echo "chgrp failed" >&2; exit 1; }
chmod g+w "$tmpdir/root-owned"
chmod g+x "$tmpdir"

# -d now removed, cuz non-POSIX

chroot --skip-chdir --user="$NON_ROOT_USERNAME" / env PATH="$PATH" \
  "$TOUCH" "$tmpdir/root-owned" || { echo "touch on root-owned file failed" >&2; exit 1; }

echo "$(basename "$0"): Success"
