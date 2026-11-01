#!/usr/bin/env bash
# Installs a built weapon pack into the game folder as mods/<pack>/mod.ff, the place the S1x / s1-mod clients load it from.
# Usage: install-pack.sh [<pack.ff>]
# Env:   GAME (game folder), WS (ZoneTool workspace, default ~/zonetool-workspace), PACK (pack name, default exo_weapons_all).
# The pack is only loaded while the client runs with fs_game=mods/<pack>: from the main menu open the console and run
#   loadmod mods/<pack>        (the client restarts itself)        or start the client with   -mod mods/<pack>
# Undo with `unloadmod` in the console and/or by deleting the folder this script creates.
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
echo "Next: start the game, open the console in the main menu and run: loadmod mods/$PACK"
