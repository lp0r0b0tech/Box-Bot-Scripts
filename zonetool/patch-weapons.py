#!/usr/bin/env python3
"""Write weapon/attachment JSON overrides that x64-zt (S1) can build into a loadable, pool-safe zone.

1. camoViewModelMaterialOverride.  weapon_def::parse reads WeaponDef.camoViewModelMaterialOverride from
the weapon JSON, but weapon_def::write never converts that pointer (only camoWorldModelMaterialOverride
is handled).  The raw in-process Material* is therefore copied into the zone, the engine's pointer loader
decodes it as an alias offset and the game crashes while loading the weapon.  Writing the field as ""
makes it a null pointer, which the engine accepts (stock weapons such as iw5_riotshieldt6_mp do the same).

2. Tracers.  The engine's tracer pool holds only 32 assets, and the stock Zombies zones plus the map already
define 17-20 of them (every map brings 13-16 tracers of its own).  The 28 weapons name 15 different tracers;
a pack tracer that duplicates a map's tracer takes a second pool slot, so the pack can overflow the pool while
the map loads (the engine then stops with "Exceeded limit of N '<type>' assets").  Every non-empty
tracerType / signatureTracerType in the patched weapons, and in the attachments they carry, is therefore
pointed at defaulttracer, a stock asset that code_post_gfx_mp already defines.  Only the look of the bullet
tracers changes.

The originals in dump/ are not touched.  The script reads a ZoneTool CSV, resolves every
`weapon,<name>` through the CSV's `addpath` lines (first match wins, like ZoneTool) and writes the
patched copy to <out-dir>/weapons/<name>.json.  Attachments the weapons list that name a tracer are
written to <out-dir>/attachments/<name>.json (the folder is cleared first, so a rerun never leaves a stale
copy that would win the search order).  Put `addpath,<out-dir>` first in the CSV.

usage (from the workspace root):  patch-weapons.py zone_source/<pack>.csv dump/<out-dir>
"""
import re
import sys
from pathlib import Path

CAMO_FIELD = re.compile(r'("camoViewModelMaterialOverride"\s*:\s*)"([^"]*)"')
WEAPON_TRACER = re.compile(r'("(?:tracerType|signatureTracerType)"\s*:\s*)"([^"]+)"')
ATTACHMENT_TRACER = re.compile(r'("name"\s*:\s*"tracerType"[^{}]*?"value"\s*:\s*)"([^"]+)"')
ATTACHMENT_LIST = re.compile(r'"attachments"\s*:\s*\[([^\]]*)\]')
DEFAULT_TRACER = "defaulttracer"


def csv_lines(path):
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line and not line.startswith(("#", "//")):
            yield [part.strip() for part in line.split(",")]


def find(search, kind, name):
    return next((p / kind / f"{name}.json" for p in search
                 if (p / kind / f"{name}.json").is_file()), None)


def retarget_tracers(pattern, text):
    """Point every named tracer at defaulttracer; returns the new text and the old tracer names."""
    old = [m.group(2) for m in pattern.finditer(text) if m.group(2) != DEFAULT_TRACER]
    new = pattern.sub(lambda m: m.group(0) if m.group(2) == DEFAULT_TRACER
                      else f'{m.group(1)}"{DEFAULT_TRACER}"', text)
    return new, old


def main(argv):
    if len(argv) != 3:
        sys.exit(__doc__)
    csv_path, out_dir = Path(argv[1]), Path(argv[2])
    search, weapons = [], []
    for fields in csv_lines(csv_path):
        if fields[0] == "addpath" and len(fields) > 1:
            path = Path(fields[1].replace("\\", "/"))
            if path.resolve() != out_dir.resolve():
                search.append(path)
        elif fields[0] == "weapon" and len(fields) > 1:
            weapons.append(fields[1])

    (out_dir / "weapons").mkdir(parents=True, exist_ok=True)
    (out_dir / "attachments").mkdir(parents=True, exist_ok=True)
    for stale in (out_dir / "attachments").glob("*.json"):
        stale.unlink()

    missing, attachments = 0, set()
    for name in weapons:
        source = find(search, "weapons", name)
        if source is None:
            print(f"{name}: NOT FOUND in any addpath")
            missing += 1
            continue
        text = source.read_text(encoding="utf-8")
        camo = CAMO_FIELD.search(text)
        text = CAMO_FIELD.sub(r'\1""', text)
        text, tracers = retarget_tracers(WEAPON_TRACER, text)
        (out_dir / "weapons" / f"{name}.json").write_text(text, encoding="utf-8")
        notes = []
        if camo and camo.group(2):
            notes.append(f"camoViewModelMaterialOverride {camo.group(2)!r} -> ''")
        if tracers:
            notes.append(f"tracers {', '.join(tracers)} -> {DEFAULT_TRACER}")
        print(f"{name}: {source.parent.parent.name}: {'; '.join(notes) or 'unchanged'}")
        for listed in ATTACHMENT_LIST.finditer(text):
            attachments.update(re.findall(r'"([^"]+)"', listed.group(1)))

    for name in sorted(attachments):
        source = find(search, "attachments", name)
        if source is None:
            continue
        text, tracers = retarget_tracers(ATTACHMENT_TRACER, source.read_text(encoding="utf-8"))
        if tracers:
            (out_dir / "attachments" / f"{name}.json").write_text(text, encoding="utf-8")
            print(f"attachment {name}: {source.parent.parent.name}: "
                  f"tracers {', '.join(tracers)} -> {DEFAULT_TRACER}")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
