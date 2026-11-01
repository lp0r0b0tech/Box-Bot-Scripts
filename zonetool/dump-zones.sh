#!/usr/bin/env bash
# One type-filtered dump per zone, each in its own ZoneTool process.
# Usage: dump-zones.sh <zone> [<zone> ...]            e.g.  dump-zones.sh mp_zombie_h2o mp_zombie_ark mp_zombie_brg
# Each process loads common_mp and techsets_common_core_mp first (the zombie zones reference assets in them), then runs
#   dumpzone s1 <zone> <types>
# One process per zone matters: the engine's image/material pools cannot be enlarged and a second big zone overflows them.
# Only the asset types a weapon pack needs are written; the zone's CSV still lists every asset. A dump is complete when the
# log has 'Zone "<zone>" dumped.' and the CSV's size is not a multiple of 4096 (a multiple means it was cut off).
# Writes one summary line per zone to $WS/logs/dump_all.log. Env: WS (default ~/zonetool-workspace), TIMEOUT, MEM.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="${WS:-$HOME/zonetool-workspace}"
FILTER=weapon,attachment,xmodel,xmodelsurfs,xanim,fx,material,image,techset,sound,loaded_sound,tracer,physpreset,phys_collmap,particlesimanimation,laser,lightdef,sndcurve,lpfcurve,reverbsendcurve,pixelshader,vertexshader,hullshader,domainshader
mkdir -p "$WS/logs"
for z in "$@"; do
  cmds="$WS/logs/cmd_dump_$z.txt"
  printf 'loadzone common_mp\nloadzone techsets_common_core_mp\ndumpzone s1 %s %s\nquit\n' "$z" "$FILTER" > "$cmds"
  rm -rf "${WS:?}/dump/$z"
  TIMEOUT="${TIMEOUT:-3000}" MEM="${MEM:-9G}" "$HERE/console-run.sh" "dump_$z" "$cmds" | tee -a "$WS/logs/dump_all.log"
  csv="$WS/dump/$z/$z.csv"
  size=$(stat -c %s "$csv" 2>/dev/null || echo 0)
  echo "  $z: csv=$size mod4096=$((size % 4096)) size=$(du -sh "$WS/dump/$z" 2>/dev/null | cut -f1)" | tee -a "$WS/logs/dump_all.log"
done
