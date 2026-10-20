#!/bin/sh
BASE=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 1
if [ "$1" = stop ]; then
    touch /tmp/xiamen-clock.stop
    exit 0
fi
case "$1" in preview|start) ;; *) exit 1 ;; esac
mkdir -p "$BASE/runtime"
# Detach before stopping the stock GUI, which also closes KUAL.
setsid sh "$BASE/clock.sh" "$1" </dev/null >>"$BASE/runtime/clock.log" 2>&1 &
exit 0
