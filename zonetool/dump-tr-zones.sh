#!/usr/bin/env bash
# Dumps stock transient zones (mp_vm_<weapon>_tr, mp_wm_<weapon>_tr, ...) so a pack recipe can find the real
# viewmodel/worldmodel geometry. Those zones are the only place that DEFINES most multiplayer weapon xmodels: the main
# zones (common_mp, patch_common_mp) only reference them, so without these dumps the builder has to copy whatever the
# running engine holds under that name (a placeholder) and the weapon renders as a red box in game.
# Usage: dump-tr-zones.sh [-n <zones per process>] <zone> [<zone> ...]
#   e.g. dump-tr-zones.sh mp_vm_m1garand_tr mp_wm_m1garand_tr
# Each process loads common_mp and techsets_common_core_mp first, then runs one "dumpzone s1 <zone> <types>" per zone.
# ZoneTool does NOT write these to dump/<zone>: every mp_vm_*/mp_wm_* zone lands in dump/weapon_models (all merged,
# one <zone>.csv each) and every other *_tr zone in dump/transient_assets (see get_dump_path in its filesystem.cpp).
# A zone whose <zone>.csv already exists there is skipped. A dump is complete when the log has 'Zone "<zone>" dumped.'
# for it and its CSV is not empty. The zones DEFINE only xmodel and xmodelsurfs (materials/techsets are references).
# One summary line per process goes to $WS/logs/dump_tr.log, one per zone ("ok"/"MISSING") is printed at the end.
# Env: WS (default ~/zonetool-workspace), TIMEOUT, MEM.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="${WS:-$HOME/zonetool-workspace}"
PER=4
if [ "${1:-}" = "-n" ]; then PER="$2"; shift 2; fi
FILTER=xmodel,xmodelsurfs,xanim,material,image,techset,physpreset,phys_collmap,pixelshader,vertexshader,hullshader,domainshader
dump_dir() {
  case "$1" in
    mp_vm_* | mp_wm_*) echo weapon_models ;;
    *_tr) echo transient_assets ;;
    *) echo "$1" ;;
  esac
}
mkdir -p "$WS/logs"
todo=()
for z in "$@"; do
  if [ -s "$WS/dump/$(dump_dir "$z")/$z.csv" ]; then
    echo "  $z: dump/$(dump_dir "$z")/$z.csv exists, skipped" | tee -a "$WS/logs/dump_tr.log"; continue
  fi
  todo+=("$z")
done
batch=0
while [ "${#todo[@]}" -gt 0 ]; do
  chunk=("${todo[@]:0:$PER}")
  todo=("${todo[@]:$PER}")
  batch=$((batch + 1))
  tag="dump_tr_$(date +%H%M%S)_$batch"
  cmds="$WS/logs/cmd_$tag.txt"
  printf 'loadzone common_mp\nloadzone techsets_common_core_mp\n' > "$cmds"
  for z in "${chunk[@]}"; do printf 'dumpzone s1 %s %s\n' "$z" "$FILTER" >> "$cmds"; done
  printf 'quit\n' >> "$cmds"
  TIMEOUT="${TIMEOUT:-1800}" MEM="${MEM:-9G}" "$HERE/console-run.sh" "$tag" "$cmds" | tee -a "$WS/logs/dump_tr.log"
  for z in "${chunk[@]}"; do
    d="$WS/dump/$(dump_dir "$z")"
    csv="$d/$z.csv"
    if grep -a -q "Zone \"$z\" dumped" "$WS/logs/$tag.clean.log" && [ -s "$csv" ]; then
      echo "  $z: ok csv_lines=$(wc -l < "$csv") xmodels=$(grep -c '^xmodel,[^,]' "$csv") surfs=$(grep -c '^xmodelsurfs,[^,]' "$csv")" | tee -a "$WS/logs/dump_tr.log"
    else
      echo "  $z: MISSING (see logs/$tag.clean.log)" | tee -a "$WS/logs/dump_tr.log"
    fi
  done
done
