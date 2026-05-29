#!/bin/sh
# Ported from coreutils: tests/touch/no-dereference.sh
# "Ensure that touch -h works." even tho it's not POSIX compliant
# busybox and GNU/coreutils support this.
set -eu

tmpdir=$(mktemp -d)
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

ln -s nowhere "$tmpdir/dangling"
> "$tmpdir/file"
ln -s "$tmpdir/file" "$tmpdir/link"

# NON-POSIX(?)
# Busybox touch doesn't support this. We won't support it either.

#if "$TOUCH" -h "$tmpdir/no-file" 2>"$tmpdir/err"; then
#  echo "touch -h on nonexistent file should have failed" >&2
#  exit 1
#fi

if cmp -s /dev/null "$tmpdir/err"; then
  echo "touch -h on nonexistent file should have printed a warning" >&2
  exit 1
fi

# -h -c on a nonexistent target should succeed silently
"$TOUCH" -h -c "$tmpdir/no-file" 2>"$tmpdir/err" || { echo "touch -h -c failed" >&2; exit 1; }
if ! cmp -s /dev/null "$tmpdir/err"; then
  echo "touch -h -c produced unexpected output" >&2
  cat "$tmpdir/err" >&2
  exit 1
fi

# -h works on regular files
"$TOUCH" -h "$tmpdir/file" || { echo "touch -h on regular file failed" >&2; exit 1; }

# -h -r uses timestamp of the symlink, not the referent
# NOTE: busybox fails here, but we pass, so it's okay ig?
"$TOUCH" -h -r "$tmpdir/dangling" "$tmpdir/file" || { echo "touch -h -r failed" >&2; exit 1; }
if [ -f "$tmpdir/nowhere" ]; then
  echo "touch -h -r should not have created the dangling symlink target" >&2
  exit 1
fi

# Changing time of a dangling symlink
"$TOUCH" -h "$tmpdir/dangling" 2>"$tmpdir/err"
case $? in
  0)
    if [ -f "$tmpdir/nowhere" ]; then
      echo "dangling symlink target should not have been created" >&2
      exit 1
    fi
    if ! cmp -s /dev/null "$tmpdir/err"; then
      echo "touch -h on dangling symlink produced unexpected output" >&2
      cat "$tmpdir/err" >&2
      exit 1
    fi
    ;;
  1)
    if grep -q 'Function not implemented' "$tmpdir/err"; then
      echo "Skipping test: utimensat not supported" >&2
      exit 77
    fi
    echo "touch -h on dangling symlink failed unexpectedly" >&2
    exit 1
    ;;
  *)
    echo "touch -h on dangling symlink returned unexpected exit code" >&2
    exit 1
    ;;
esac

# -m -h -d changes symlink mtime, not referent
"$TOUCH" -m -h -d 2009-10-10 "$tmpdir/link" || { echo "touch -m -h -d failed" >&2; exit 1; }

case $(stat --format=%y "$tmpdir/link") in
  2009-10-10*) ;;
  *) echo "symlink mtime was not updated correctly" >&2; exit 1 ;;
esac

case $(stat --format=%y "$tmpdir/file") in
  2009-10-10*)
    echo "referent mtime should not have changed" >&2
    exit 1
    ;;
esac

# Not POSIX, these also fail in busybox.

# touch -h - should write to stdout, not dereference
# "$TOUCH" -h - > "$tmpdir/file" || { echo "touch -h - failed" >&2; exit 1; }

#if env test -w /dev/stdout >/dev/null && env test ! -w /dev/stdout >&-; then
#  "$TOUCH" -h - >&- 2>/dev/null && { echo "touch -h - with closed stdout should have failed" >&2; exit 1; }
#  "$TOUCH" -h -c - >&- 2>/dev/null || { echo "touch -h -c - with closed stdout failed" >&2; exit 1; }
#fi

echo "$(basename "$0"): Success"
