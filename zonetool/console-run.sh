#!/usr/bin/env bash
# Runs ZoneTool in console mode, feeding it the lines of a command file (see CMDS in run-zonetool.sh).
# Usage: console-run.sh <tag> <cmdfile>
# Writes $WS/logs/<tag>.log (raw) and $WS/logs/<tag>.clean.log (colour codes and CRs stripped) and prints one verdict line:
#   <tag>: <seconds>s assets=<n> dumped=<n> fatal=[<screenshot of a fatal-error dialog>] crash=[<crash line>]
# The wrapper's exit status is always 0, so that verdict line is the way to tell whether a run worked.
# Env: WS (default ~/zonetool-workspace), TIMEOUT (seconds, default 900), MEM (default 9G).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="${WS:-$HOME/zonetool-workspace}"
tag="${1:?usage: console-run.sh <tag> <cmdfile>}"
cmds="$(readlink -f "${2:?usage: console-run.sh <tag> <cmdfile>}")"
cd "$WS" || exit 1
mkdir -p logs

start=$(date +%s)
CMDS="$cmds" TIMEOUT="${TIMEOUT:-900}" MEM="${MEM:-9G}" "$HERE/run-zonetool.sh" < /dev/null > "logs/$tag.log" 2>&1
end=$(date +%s)

sed -E 's/\x1b\[[0-9;?]*[a-zA-Z]//g' "logs/$tag.log" | tr -d '\r' > "logs/$tag.clean.log"
assets=$(grep -a -c 'Loading asset' "logs/$tag.clean.log")
fatal=$(grep -a -o 'fatal-error dialog, screenshot: .*' "logs/$tag.clean.log" | head -1)
crash=$(grep -a -o 'zonetool.exe crashed: .*' "logs/$tag.clean.log" | head -1)
dumped=$(grep -a -c 'Zone ".*" dumped' "logs/$tag.clean.log")
echo "$tag: $((end - start))s assets=$assets dumped=$dumped fatal=[${fatal##*: }] crash=[$crash]"
