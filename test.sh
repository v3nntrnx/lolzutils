#!/bin/sh

zig build

: "${TOUCH:=./zig-out/bin/touch}"
export TOUCH

: "${PARALLEL:=true}"

for f in ./tests/touch/*.sh; do
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

if [ "$PARALLEL" = "true" ]; then
    wait
fi
