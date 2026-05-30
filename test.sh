#!/bin/sh
zig build
export ZIG_OUT="$(pwd)/zig-out"
: "${PARALLEL:=true}"
: "${TOUCH:=./zig-out/bin/touch}"
export TOUCH

run_tests() {
    dir="$1"
    for f in "$dir"/*.sh; do
        if [ "$PARALLEL" = "true" ]; then
            AMPERSAND="&"
        else
            AMPERSAND=""
        fi
        if [ "$(basename "$f")" = "now-owned-by-other.sh" ]; then
            eval "sudo -E sh \"\$f\" $AMPERSAND"
        else
            eval "sh \"\$f\" $AMPERSAND"
        fi
    done
}

run_tests ./tests/crypto
run_tests ./tests/touch

if [ "$PARALLEL" = "true" ]; then
    wait
fi