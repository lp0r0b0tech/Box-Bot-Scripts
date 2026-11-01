#!/usr/bin/env python3
"""Estimate how full the engine's asset pools get when a Zombies map loads with a weapon pack mounted.

The engine keeps one fixed-size pool per asset type and stops with "Exceeded limit of N '<type>' assets" when a
pool is full.  The estimate uses the asset lists of the dumped zones (dump/<zone>/<zone>.csv, see csv-zones.sh)
and of the pack (the "Loading asset" lines of logs/verify_<pack>.log, written by build-verify.sh), and this
model of the loader (read from the game binary, not observed in the game):

  - every asset a loading zone defines takes a pool slot;
  - an asset whose name is already loaded takes no extra slot when both zones have the same load flags (the new
    copy is dropped), and a second slot when the flags differ;
  - the pack's mod zone has the flags of the "base" zones below, the "other" zones have different ones.

The zones that are loaded while a Zombies map loads (read with watch-s1x-fds.sh; ui_mp and ui_zm_mp are unloaded
when the map starts, so they do not count):
  base:   code_pre_gfx_mp, code_post_gfx_mp, code_post_gfx_zm_mp, common_zm_mp
  other:  common_bots_mp, common_core_zm_mp, and the map's mp_zombie_<map>, mp_zombie_<map>_load, mp_zombie_<map>_path
Each of them comes with its patch_<zone>, eng_<zone> and eng_patch_<zone> zones.  A zone without a dump is skipped
and listed; the ones that are missing by default (code_pre_gfx_mp, common_bots_mp and the map's _load and _path
zones) are small, so expect the real use to be a little higher.

So a pack asset costs nothing when a base zone already defines it and one slot otherwise, and the other zones'
assets always cost a slot.  The "worst" column adds the pack assets the base zones define, which is what the pack
would cost if the flags assumption were wrong.

Usage (from anywhere):  pool-estimate.py [pack]  [map ...]      defaults: exo_weapons_all, lab ark brg h2o
Env:    WS (workspace, default ~/zonetool-workspace); needs dump/<zone>/<zone>.csv for the zones above, and
        PACK_LOG to read the pack's assets from another log than $WS/logs/verify_<pack>.log.
        EXTRA_BASE: more zones to treat as loaded before the pack with the base flags (default none).
"""
import collections
import os
import re
import sys
from pathlib import Path

BASE_ZONES = ["code_pre_gfx_mp", "code_post_gfx_mp", "code_post_gfx_zm_mp", "common_zm_mp"]
OTHER_ZONES = ["common_bots_mp", "common_core_zm_mp"]

# Pool sizes of the retail game (g_poolSize in s1_mp64_ship.exe).  Do not read them from a running ZoneTool: its
# init_zonetool() enlarges the pools (xanim, sound, loaded_sound, weapon, attachment, localize, luafile,
# leaderboarddef, reverbpreset x2; computeshader and equipsndtable x4; vertexdecl x6; impactfx x10), which is why
# -verifyzone accepts a pack that the game then rejects.  The S1x client raises xmodel to 8,832 (stock 4,416) and
# font to 48 (stock 32).  A script or a pack cannot change any of them.
LIMITS = {
    "physpreset": 128, "phys_collmap": 256, "physwaterpreset": 16, "physconstraint": 128,
    "xanim": 5800, "xmodelsurfs": 5248, "xmodel": 8832, "material": 11648, "techset": 2304, "image": 13792,
    "computeshader": 256, "vertexshader": 49152, "hullshader": 12288, "domainshader": 12288,
    "pixelshader": 72864, "vertexdecl": 512,
    "sound": 16000, "soundsubmix": 256, "sndcurve": 64, "lpfcurve": 64, "reverbsendcurve": 64, "sndcontext": 64,
    "loaded_sound": 7000, "lightdef": 32, "font": 48, "menufile": 128, "menu": 910, "animclass": 16,
    "localize": 13600, "attachment": 128, "weapon": 700, "fx": 2048, "impactfx": 4, "surfacefx": 6,
    "rawfile": 1024, "scriptfile": 768, "stringtable": 400, "leaderboarddef": 128, "structureddatadef": 24,
    "tracer": 32, "vehicle": 32, "netconststrings": 128, "reverbpreset": 64, "luafile": 384, "scriptable": 128,
    "equipsndtable": 1, "vectorfield": 128, "dopplerpreset": 64, "particlesimanimation": 32, "laser": 32,
    "skeletonscript": 16, "clut": 32,
}


def with_variants(zones):
    return [name for zone in zones for name in (zone, f"patch_{zone}", f"eng_{zone}", f"eng_patch_{zone}")]


def zone_assets(ws, zone):
    """Assets a zone defines (its references to other zones' assets do not take a slot): {type: {names}}, or None
    when the zone has not been dumped."""
    path = ws / "dump" / zone / f"{zone}.csv"
    if not path.is_file():
        return None
    out = collections.defaultdict(set)
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        parts = line.rstrip("\r").split(",")
        if len(parts) >= 2 and parts[0] and parts[1]:
            out[parts[0]].add(",".join(parts[1:]))
    return out


def merged(ws, zones, skipped):
    """The union of the zones' assets; zones without a dump are added to the set `skipped`."""
    out = collections.defaultdict(set)
    for zone in zones:
        assets = zone_assets(ws, zone)
        if assets is None:
            skipped.add(zone)
            continue
        for kind, names in assets.items():
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
    skipped = set()
    base = merged(ws, with_variants(BASE_ZONES) + os.environ.get("EXTRA_BASE", "").split(), skipped)
    other = merged(ws, with_variants(OTHER_ZONES), skipped)
    pack_set = pack_assets(log)
    print(f"{pack}: {sum(len(v) for v in pack_set.values())} assets from {log.name}")
    for short in maps:
        zone = short if short.startswith("mp_") else f"mp_zombie_{short}"
        own = merged(ws, with_variants([zone]) + [f"{zone}_load", f"{zone}_path"], skipped)
        rows = []
        for kind, limit in LIMITS.items():
            shared = len(pack_set[kind] & base[kind])
            added = len(pack_set[kind]) - shared
            stock = len(base[kind]) + len(other[kind]) + len(own[kind])
            rows.append(((stock + added) / limit, kind, limit, stock, added, stock + added, stock + len(pack_set[kind])))
        print(f"\n{zone}: slots used = base zones + other zones + map zones + pack assets the base zones lack")
        print(f"{'pool':<16}{'limit':>7}{'stock':>7}{'%':>6}{'pack':>7}{'used':>7}{'%':>6}{'worst':>7}{'%':>6}")
        for frac, kind, limit, stock, added, use, worst in sorted(rows, reverse=True)[:8]:
            print(f"{kind:<16}{limit:>7}{stock:>7}{stock / limit * 100:>6.1f}{added:>7}{use:>7}{frac * 100:>6.1f}"
                  f"{worst:>7}{worst / limit * 100:>6.1f}{'  OVER' if worst > limit else ''}")
    if skipped:
        print(f"\nnot dumped, so not counted: {' '.join(sorted(skipped))}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
