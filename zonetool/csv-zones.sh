#!/usr/bin/env bash
# Writes only the asset list (dump/<zone>/<zone>.csv, lines "<type>,<name>"; a reference has an empty second field,
# i.e. "<type>,,<name>") of each zone, one ZoneTool process per zone. Nothing but rawfiles is dumped to disk, so it is cheap.
# Usage: [PRELOAD="<zone> ..."] csv-zones.sh <zone> [<zone> ...]       e.g.  csv-zones.sh common_core_mp ui_mp
# By default no other zone is loaded first, which is enough for the small base and patch zones. A map zone references
# shaders of techsets_common_core_mp and stops with "Could not load default asset 'nodefault' ..." unless that zone (and
# common_mp) is loaded first, so for a map: PRELOAD="common_mp techsets_common_core_mp" csv-zones.sh mp_zombie_lab
# A CSV is complete when the log has 'Zone "<zone>" dumped.' (verdict dumped=1) and its size is not a multiple of 4096.
# One summary line per zone goes to $WS/logs/csv_all.log. A zone whose dump/<zone> already exists is skipped.
# Env: WS (default ~/zonetool-workspace), TIMEOUT, MEM, PRELOAD, FORCE (set it to replace an existing dump/<zone>).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="${WS:-$HOME/zonetool-workspace}"
mkdir -p "$WS/logs"
for z in "$@"; do
  # dump/<zone> may hold a full dump that a pack recipe reads (addpath), so an existing one is never replaced
  if [ -e "$WS/dump/$z" ] && [ -z "${FORCE:-}" ]; then
    echo "  $z: dump/$z exists, skipped (FORCE=1 replaces it)" | tee -a "$WS/logs/csv_all.log"
    continue
  fi
  cmds="$WS/logs/cmd_csv_$z.txt"
  : > "$cmds"
  for p in ${PRELOAD:-}; do printf 'loadzone %s\n' "$p" >> "$cmds"; done
  printf 'dumpzone s1 %s rawfile\nquit\n' "$z" >> "$cmds"
  rm -rf "${WS:?}/dump/$z"
  TIMEOUT="${TIMEOUT:-1800}" MEM="${MEM:-9G}" "$HERE/console-run.sh" "csv_$z" "$cmds" | tee -a "$WS/logs/csv_all.log"
  csv="$WS/dump/$z/$z.csv"
  size=$(stat -c %s "$csv" 2>/dev/null || echo 0)
  echo "  $z: csv=$size mod4096=$((size % 4096)) lines=$(wc -l < "$csv" 2>/dev/null || echo 0)" | tee -a "$WS/logs/csv_all.log"
done
