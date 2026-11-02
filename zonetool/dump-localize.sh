#!/usr/bin/env bash
# Dumps only the localized strings (localize assets) of English zones, all in ONE ZoneTool process.
# Usage: dump-localize.sh <eng_zone> [<eng_zone> ...]      e.g.  dump-localize.sh eng_mp_zombie_h2o eng_mp_zombie_ark
# Each zone lands in dump/<zone>/localizedstrings/<KEY> (plain text, value only, no extension). Add the directory as an
# `addpath` line to a pack CSV and a build will use the strings.
# Do not pass more than ~10 zones at once and do not add `unloadzones`: loaded zones pile up, and zones that define
# fonts (eng_code_post_gfx*, eng_patch_code_*gfx*) hit the engine's 64-font limit, while unloading an English zone
# ends in a fatal "Could not load default asset for asset type 'localize'" dialog.
# Env: WS (default ~/zonetool-workspace), TIMEOUT (seconds, default 900), MEM (default 9G).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="${WS:-$HOME/zonetool-workspace}"
[ $# -gt 0 ] || { echo "usage: dump-localize.sh <eng_zone> [<eng_zone> ...]" >&2; exit 2; }
mkdir -p "$WS/logs"
cmds="$WS/logs/cmd_dump_localize.txt"
{ for z in "$@"; do echo "dumpzone s1 $z localize"; done; echo quit; } > "$cmds"
"$HERE/console-run.sh" dump_localize "$cmds"
