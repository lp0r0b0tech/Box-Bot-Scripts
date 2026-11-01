#!/usr/bin/env bash
# Builds a ZoneTool "shadow workspace" for Call of Duty: Advanced Warfare.
#
# The real game folder is only ever READ: big data (.ff / .pak) is symlinked, small files are
# copied, and everything ZoneTool writes (dump/, zone/, zonetool/, prefix) lives in the workspace.
set -euo pipefail

GAME="${GAME:-$HOME/.local/share/Steam/steamapps/common/Call of Duty Advanced Warfare}"
WS="${WS:-$HOME/zonetool-workspace}"
ZT_ZIP="${ZT_ZIP:-}"   # optional path to an already-downloaded Release.zonetool.zip

[ -f "$GAME/s1_mp64_ship.exe" ] || { echo "Game binary not found in: $GAME" >&2; exit 1; }
# Do NOT create zone/: with it present the engine looks for zone/<lang>/<lang>_<name>.ff and the
# Steam layout (fastfiles in the root) stops working. Build output lands in the workspace root.
mkdir -p "$WS"/{dump,zonetool,zonetool_paths,zone_source,players2,main,logs,english}

if [ ! -f "$WS/zonetool.exe" ]; then
  if [ -z "$ZT_ZIP" ]; then
    ZT_ZIP="$WS/Release.zonetool.zip"
    gh release download latest -R Joelrau/x64-zt -p Release.zonetool.zip -D "$WS" --clobber
  fi
  unzip -o -j "$ZT_ZIP" zonetool.exe -d "$WS" >/dev/null
fi
# Upstream bug: the FX decal writer reads a non-existent 3rd material and crashes -buildzone (see patch-zonetool.py).
python3 "$(dirname "${BASH_SOURCE[0]}")/patch-zonetool.py" "$WS/zonetool.exe"

# Real copies: the game binary, its DLLs and small data folders.
for f in s1_mp64_ship.exe bink2w64.dll ControllerManager.dll d3dcompiler_46.dll nvToolsExt64_1.dll \
         vcomp110.dll XGamepad.dll tier0_s.dll vstdlib_s.dll steam_api64.dll; do
  [ -f "$GAME/$f" ] && cp -n "$GAME/$f" "$WS/$f"
done
cp -rn "$GAME/APEX" "$GAME/data" "$WS/"
cp -n "$GAME/main/fileSysCheck.cfg" "$WS/main/"   # the game refuses to start without it

# The game imports d3d11/dxgi; wine's builtin ones need vkd3d, so use DXVK's from GE-Proton instead.
GE="${GE:-$HOME/.local/share/Steam/compatibilitytools.d/GE-Proton11-11-x86_64}"
cp -n "$GE/files/lib/wine/dxvk/x86_64-windows/d3d11.dll" "$GE/files/lib/wine/dxvk/x86_64-windows/dxgi.dll" "$WS/"

# Symlinks: every fastfile and pak (~79 GB) so nothing is duplicated and nothing can write back.
find "$GAME" -maxdepth 1 -type f \( -name '*.ff' -o -name '*.pak' \) -exec ln -sfn {} "$WS"/ \;
(cd "$GAME/english" && find . -type d -exec mkdir -p "$WS/english/{}" \; \
  && find . -type f -exec ln -sfn "$GAME/english/{}" "$WS/english/{}" \;)

echo "Shadow workspace ready: $WS"
echo "  fastfiles linked: $(find "$WS" -maxdepth 1 -name '*.ff' | wc -l)"
echo "  paks linked:      $(find "$WS" -maxdepth 1 -name '*.pak' | wc -l)"
