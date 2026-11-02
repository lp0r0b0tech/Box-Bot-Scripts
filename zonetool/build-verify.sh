#!/usr/bin/env bash
# Build zone_source/<name>.csv with ZoneTool, then load the result in ZoneTool's engine (-verifyzone).
# Prints one verdict line per zone.   Usage: build-verify.sh <name> [<name> ...]
# Env: WS (default ~/zonetool-workspace), TIMEOUT (seconds per ZoneTool run, default 600), MEM (default 9G).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="${WS:-$HOME/zonetool-workspace}"
cd "$WS" || exit 1

strip_log() { sed -E 's/\x1b\[[0-9;?]*[a-zA-Z]//g' "$1" | tr -d '\r'; }

for name in "$@"; do
  rm -f "$name.ff"
  TIMEOUT="${TIMEOUT:-600}" MEM="${MEM:-9G}" "$HERE/run-zonetool.sh" -buildzone "$name" </dev/null >"logs/build_$name.log" 2>&1
  if [ ! -s "$name.ff" ]; then
    why="$(strip_log "logs/build_$name.log" | grep -a -E 'FATAL|crashed|ERROR|fatal-error dialog' | head -2 | tr '\n' ' ')"
    echo "$name: BUILD FAILED $why"
    continue
  fi
  size="$(stat -c %s "$name.ff")"
  TIMEOUT="${TIMEOUT:-600}" MEM="${MEM:-9G}" "$HERE/run-zonetool.sh" -verifyzone "$name" </dev/null >"logs/verify_$name.log" 2>&1
  n="$(strip_log "logs/verify_$name.log" | grep -a -c 'Loading asset')"
  last="$(strip_log "logs/verify_$name.log" | grep -a 'Loading asset' | tail -1 | sed -E 's/.*Loading asset "([^"]*)" of type ([a-z_]*)\./\2 \1/')"
  if strip_log "logs/verify_$name.log" | grep -a -q 'zonetool.exe crashed'; then verdict=CRASH; else verdict=OK; fi
  echo "$name: built ${size} bytes; verify $verdict after $n assets; last=$last"
done
