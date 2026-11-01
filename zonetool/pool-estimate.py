#!/usr/bin/env python3
"""Estimate how full the engine's asset pools get when a Zombies map loads with a weapon pack mounted.

The engine keeps one fixed-size pool per asset type and stops with "Exceeded limit of N '<type>' assets" when a
pool is full.  The estimate uses the asset lists of the dumped zones (dump/<zone>/<zone>.csv, see csv-zones.sh)
and of the pack (the "Loading asset" lines of logs/verify_<pack>.log, written by build-verify.sh), and this
model of the loader (read from the game binary, not observed in the game):

  - every asset a loading zone defines takes a pool slot;
  - an asset whose name is already loaded takes no extra slot when both zones have the same load flags (the new
    copy is dropped), and a second slot when the flags differ;
  - the pack's mod zone has the flags of code_post_gfx_mp and common_zm_mp, a map zone has different ones;
  - in Zombies the renderer zones load in this order: code_post_gfx_mp, code_post_gfx_zm_mp, ui_mp, ui_zm_mp,
    common_zm_mp, the mod zone, and only then the map's zones.

So a pack asset costs nothing when one of those five base zones already defines it and one slot otherwise, and a
map's own assets always cost a slot.  The "worst" column adds the pack assets the base zones define, which is
what the pack would cost if the flags assumption were wrong.  Not modelled: the map's _load, _path and English
(eng_) zones and anything the game loads at run time, so expect the real use to be a little higher.

Usage (from anywhere):  pool-estimate.py [pack]  [map ...]      defaults: exo_weapons_all, lab ark brg h2o
Env:    WS (workspace, default ~/zonetool-workspace); needs dump/<zone>/<zone>.csv for the zones below, and
        PACK_LOG to read the pack's assets from another log than $WS/logs/verify_<pack>.log.
        EXTRA_BASE: more zones to treat as loaded before the pack with the base flags (default none).  Which zones a
        Zombies map really loads is best read from watch-s1x-fds.sh, e.g. a pessimistic case is
        EXTRA_BASE="patch_code_post_gfx_mp common_core_mp patch_common_core_mp techsets_common_core_mp".
"""
import collections
import os
import re
import sys
from pathlib import Path

BASE_ZONES = ["code_post_gfx_mp", "code_post_gfx_zm_mp", "ui_mp", "ui_zm_mp", "common_zm_mp"]

# Pool sizes from the game's pool table (g_poolSize in s1_mp64_ship.exe; stock xmodel is 4,416 and the client raises it
# to 8,832). A script or a pack cannot change them.
LIMITS = {
    "physpreset": 128, "phys_collmap": 256, "physwaterpreset": 16, "physconstraint": 128,
    "xanim": 11600, "xmodelsurfs": 5248, "xmodel": 8832, "material": 11648, "techset": 2304, "image": 13792,
    "computeshader": 1024, "vertexshader": 49152, "hullshader": 12288, "domainshader": 12288,
    "pixelshader": 72864, "vertexdecl": 3072,
    "sound": 32000, "soundsubmix": 256, "sndcurve": 64, "lpfcurve": 64, "reverbsendcurve": 64, "sndcontext": 64,
    "loaded_sound": 14000, "lightdef": 32, "font": 64, "menufile": 128, "menu": 910, "animclass": 16,
    "localize": 27200, "attachment": 256, "weapon": 1400, "fx": 2048, "impactfx": 40, "surfacefx": 6,
    "rawfile": 1024, "scriptfile": 768, "stringtable": 400, "leaderboarddef": 256, "structureddatadef": 24,
    "tracer": 32, "vehicle": 32, "netconststrings": 128, "reverbpreset": 128, "luafile": 768, "scriptable": 128,
    "equipsndtable": 4, "vectorfield": 128, "dopplerpreset": 64, "particlesimanimation": 32, "laser": 32,
    "skeletonscript": 16, "clut": 32,
}


def zone_assets(ws, zone):
    """Assets a zone defines (its references to other zones' assets do not take a slot): {type: {names}}."""
    path = ws / "dump" / zone / f"{zone}.csv"
    if not path.is_file():
        sys.exit(f"missing {path} (dump the zone's asset list with csv-zones.sh)")
    out = collections.defaultdict(set)
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        parts = line.rstrip("\r").split(",")
        if len(parts) >= 2 and parts[0] and parts[1]:
            out[parts[0]].add(",".join(parts[1:]))
    return out


def merged(ws, zones):
    out = collections.defaultdict(set)
    for zone in zones:
        for kind, names in zone_assets(ws, zone).items():
            out[kind] |= names
    return out


def pack_assets(log):
    text = re.sub(r"\x1b\[[0-9;?]*[a-zA-Z]", "", log.read_text(encoding="utf-8", errors="replace"))
    out = collections.defaultdict(set)
    for name, kind in re.findall(r'Loading asset "([^"]*)" of type ([a-z_]+)', text):
        out[kind].add(name)
    return out


def main(argv):
    ws = Path(os.environ.get("WS", Path.home() / "zonetool-workspace"))
    pack = argv[1] if len(argv) > 1 else "exo_weapons_all"
    maps = argv[2:] or ["lab", "ark", "brg", "h2o"]
    log = Path(os.environ.get("PACK_LOG", ws / "logs" / f"verify_{pack}.log"))
    if not log.is_file():
        sys.exit(f"missing {log} (build the pack with build-verify.sh {pack})")
    base = merged(ws, BASE_ZONES + os.environ.get("EXTRA_BASE", "").split())
    pack_set = pack_assets(log)
    print(f"{pack}: {sum(len(v) for v in pack_set.values())} assets from {log.name}")
    for short in maps:
        zone = short if short.startswith("mp_") else f"mp_zombie_{short}"
        own = merged(ws, [zone, f"patch_{zone}"])
        rows = []
        for kind, limit in LIMITS.items():
            shared = len(pack_set[kind] & base[kind])
            added = len(pack_set[kind]) - shared
            use = len(base[kind]) + len(own[kind]) + added
            rows.append((use / limit, kind, limit, len(base[kind]), len(own[kind]), added, shared, use))
        print(f"\n{zone}: slots used = base zones + map zone + pack assets the base zones lack")
        print(f"{'pool':<16}{'limit':>7}{'base':>7}{'map':>7}{'pack':>7}{'used':>7}{'%':>6}{'worst':>7}{'%':>6}")
        for frac, kind, limit, nbase, nown, added, shared, use in sorted(rows, reverse=True)[:8]:
            worst = use + shared
            print(f"{kind:<16}{limit:>7}{nbase:>7}{nown:>7}{added:>7}{use:>7}{frac * 100:>6.1f}"
                  f"{worst:>7}{worst / limit * 100:>6.1f}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
