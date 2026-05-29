#!/bin/sh
# Ported from coreutils: tests/touch/trailing-slash.sh
set -eu

tmpdir=$(mktemp -d)
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

ln -s nowhere "$tmpdir/dangling"
ln -s "$tmpdir/loop" "$tmpdir/loop"
> "$tmpdir/file"
ln -s "$tmpdir/file" "$tmpdir/link1"
mkdir "$tmpdir/dir"
ln -s "$tmpdir/dir" "$tmpdir/link2"

# Trailing slash only valid on directory or symlink-to-directory
"$TOUCH" "$tmpdir/no-file/" 2>/dev/null && { echo "touch no-file/ should have failed" >&2; exit 1; }
"$TOUCH" "$tmpdir/file/" 2>/dev/null && { echo "touch file/ should have failed" >&2; exit 1; }
"$TOUCH" "$tmpdir/dangling/" 2>/dev/null && { echo "touch dangling/ should have failed" >&2; exit 1; }
"$TOUCH" "$tmpdir/loop/" 2>/dev/null && { echo "touch loop/ should have failed" >&2; exit 1; }

if ls "$tmpdir/link1/" 2>/dev/null; [ $? = 2 ]; then
  "$TOUCH" "$tmpdir/link1/" 2>/dev/null && { echo "touch link1/ should have failed" >&2; exit 1; }
fi

"$TOUCH" "$tmpdir/dir/" || { echo "touch dir/ failed" >&2; exit 1; }

# -c silences ENOENT but not ENOTDIR or ELOOP
"$TOUCH" -c "$tmpdir/no-file/" || { echo "touch -c no-file/ failed" >&2; exit 1; }
"$TOUCH" -c "$tmpdir/file/" 2>/dev/null && { echo "touch -c file/ should have failed" >&2; exit 1; }
"$TOUCH" -c "$tmpdir/dangling/" || { echo "touch -c dangling/ failed" >&2; exit 1; }
"$TOUCH" -c "$tmpdir/loop/" 2>/dev/null && { echo "touch -c loop/ should have failed" >&2; exit 1; }

if ls "$tmpdir/link1/" 2>/dev/null; [ $? = 2 ]; then
  "$TOUCH" -c "$tmpdir/link1/" 2>/dev/null && { echo "touch -c link1/ should have failed" >&2; exit 1; }
fi

"$TOUCH" -c "$tmpdir/dir/" || { echo "touch -c dir/ failed" >&2; exit 1; }

if [ -f "$tmpdir/no-file" ]; then
  echo "no-file should not have been created" >&2
  exit 1
fi
if [ -f "$tmpdir/nowhere" ]; then
  echo "nowhere should not have been created" >&2
  exit 1
fi

# Trailing slash dereferences symlink even with -h
"$TOUCH" -d 2009-10-10 -h "$tmpdir/link2/" || { echo "touch -d -h link2/ failed" >&2; exit 1; }
"$TOUCH" -h -r "$tmpdir/link2/" "$tmpdir/file" || { echo "touch -h -r link2/ file failed" >&2; exit 1; }

case $(stat --format=%y "$tmpdir/dir") in
  2009-10-10*) ;;
  *) echo "dir mtime should be 2009-10-10" >&2; exit 1 ;;
esac

case $(stat --format=%y "$tmpdir/link2") in
  2009-10-10*) echo "link2 mtime should not be 2009-10-10" >&2; exit 1 ;;
esac

case $(stat --format=%y "$tmpdir/file") in
  2009-10-10*) ;;
  *) echo "file mtime should be 2009-10-10" >&2; exit 1 ;;
esac

echo "$(basename "$0"): Success"
