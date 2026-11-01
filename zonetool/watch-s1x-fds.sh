#!/usr/bin/env bash
# Logs which fastfiles (.ff) a running s1x.exe has open, with timestamps. A game that dies while loading a map
# then leaves a record of the zones it had mounted and the last ones it opened.
# Read-only: it only lists /proc/<pid>/fd. Start it before the game, stop it with Ctrl+C.
# Usage: watch-s1x-fds.sh [logfile]       (default /tmp/s1x-fd-watch.log)
# Env:   INTERVAL (seconds between samples, default 0.25), PROC (process name, default s1x.exe)
set -u
LOG="${1:-/tmp/s1x-fd-watch.log}"
INTERVAL="${INTERVAL:-0.25}"
PROC="${PROC:-s1x.exe}"

ts() { date '+%H:%M:%S.%3N'; }

open_zones() {
  find "/proc/$1/fd" -maxdepth 1 -type l -printf '%l\n' 2>/dev/null \
    | grep -a '\.ff$' | sed 's|.*/Call of Duty Advanced Warfare/||' | sort -u
}

echo "$(ts) waiting for $PROC" >>"$LOG"
while :; do
  pid="$(pgrep -x "$PROC" | head -n 1)"
  [ -n "$pid" ] || { sleep 1; continue; }
  started=$SECONDS
  echo "$(ts) $PROC pid $pid started" >>"$LOG"
  prev=""
  while [ -d "/proc/$pid" ]; do
    cur="$(open_zones "$pid")"
    while read -r f; do [ -n "$f" ] && echo "$(ts) + $f" >>"$LOG"; done \
      < <(comm -13 <(printf '%s\n' "$prev") <(printf '%s\n' "$cur"))
    while read -r f; do [ -n "$f" ] && echo "$(ts) - $f" >>"$LOG"; done \
      < <(comm -23 <(printf '%s\n' "$prev") <(printf '%s\n' "$cur"))
    prev="$cur"
    sleep "$INTERVAL"
  done
  echo "$(ts) $PROC pid $pid exited after $((SECONDS - started)) s" >>"$LOG"
done
