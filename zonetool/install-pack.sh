#!/usr/bin/env bash
# Installs a built weapon pack into the game folder as mods/<pack>/mod.ff, the place the S1x / s1-mod clients load it from.
# Usage: install-pack.sh [<pack.ff>]
# Env:   GAME (game folder), WS (ZoneTool workspace, default ~/zonetool-workspace), PACK (pack name, default exo_weapons_all).
# The pack is only loaded while the client runs with fs_game=mods/<pack>. Start the client with
#   +set fs_game mods/<pack>    (CB Servers launcher: Game Settings > Advanced > Launch Options)
# or, from the main-menu console, run   loadmod mods/<pack>   (sets fs_game and runs vid_restart; no relaunch).
# Undo by clearing the launch option / running `unloadmod`, and/or by deleting the folder this script creates.
set -euo pipefail

GAME="${GAME:-$HOME/.local/share/Steam/steamapps/common/Call of Duty Advanced Warfare}"
WS="${WS:-$HOME/zonetool-workspace}"
PACK="${PACK:-exo_weapons_all}"
SRC="${1:-$WS/$PACK.ff}"

[ -s "$SRC" ] || { echo "Pack not found: $SRC (build it with build-verify.sh $PACK)" >&2; exit 1; }
[ -f "$GAME/s1_mp64_ship.exe" ] || { echo "Game binary not found in: $GAME" >&2; exit 1; }

dest="$GAME/mods/$PACK"
mkdir -p "$dest"
cp -f "$SRC" "$dest/mod.ff"
cmp -s "$SRC" "$dest/mod.ff" || { echo "Copy to $dest/mod.ff failed verification" >&2; exit 1; }

echo "Installed $dest/mod.ff ($(stat -c %s "$dest/mod.ff") bytes)"
echo "Next: start the game with   +set fs_game mods/$PACK   (CB Servers launcher: Game Settings > Advanced > Launch Options)."
echo "      Or, in the main-menu console, run: loadmod mods/$PACK"
