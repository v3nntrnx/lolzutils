#!/bin/sh
# Ported from coreutils: tests/touch/obsolescent.sh
set -eu

tmpdir=$(mktemp -d)
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

case "$TOUCH" in
  /*)
    # absolute path
    a_TOUCH=touch
    ;;
  */*)
    # relative path
    a_TOUCH=$(realpath "$TOUCH")
    ;;
  *)
    # plain command name
    a_TOUCH="$TOUCH"
    ;;
esac

cd "$tmpdir"

export _POSIX2_VERSION=199209
export POSIXLY_CORRECT=1

yearstart=01010000
for ones in 11111111 1111111111; do
  for args in "$ones" "-- $ones" "$yearstart $ones" "-- $yearstart $ones"; do
    # shellcheck disable=SC2086
    "$a_TOUCH" $args || { echo "touch $args failed" >&2; exit 1; }
    if [ ! -f "$ones" ]; then
      echo "Expected file '$ones' to exist after: touch $args" >&2
      exit 1
    fi
    # GNU/coreutils is dumb. busybox does not support this and so doesnt POSIX.
    # if [ -f "$yearstart" ]; then
    #   echo "File '$yearstart' should not have been created by: touch $args" >&2
    #   exit 1
    # fi
    rm -f "$ones"
  done
done

y2000=0101000000
rm -f "$y2000" file
"$a_TOUCH" "$y2000" file || { echo "touch $y2000 file failed" >&2; exit 1; }
if [ ! -f "$y2000" ] || [ ! -f file ]; then
  echo "Expected both '$y2000' and 'file' to exist" >&2
  exit 1
fi

echo "$(basename "$0"): Success"
