#!/usr/bin/env python3
"""Write weapon JSON overrides that x64-zt (S1) can build into a loadable zone.

weapon_def::parse reads WeaponDef.camoViewModelMaterialOverride from the weapon JSON, but
weapon_def::write never converts that pointer (only camoWorldModelMaterialOverride is handled).
The raw in-process Material* is therefore copied into the zone, the engine's pointer loader decodes
it as an alias offset and the game crashes while loading the weapon.  Writing the field as "" makes
it a null pointer, which the engine accepts (stock weapons such as iw5_riotshieldt6_mp do the same).

The originals in dump/ are not touched.  The script reads a ZoneTool CSV, resolves every
`weapon,<name>` through the CSV's `addpath` lines (first match wins, like ZoneTool) and writes the
patched copy to <out-dir>/weapons/<name>.json.  Put `addpath,<out-dir>` first in the CSV.

usage (from the workspace root):  patch-weapons.py zone_source/<pack>.csv dump/<out-dir>
"""
import re
import sys
from pathlib import Path

FIELD = re.compile(r'("camoViewModelMaterialOverride"\s*:\s*)"([^"]*)"')


def csv_lines(path):
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line and not line.startswith(("#", "//")):
            yield [part.strip() for part in line.split(",")]


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
    missing = 0
    for name in weapons:
        source = next((p / "weapons" / f"{name}.json" for p in search
                       if (p / "weapons" / f"{name}.json").is_file()), None)
        if source is None:
            print(f"{name}: NOT FOUND in any addpath")
            missing += 1
            continue
        text = source.read_text(encoding="utf-8")
        old = FIELD.search(text)
        patched = FIELD.sub(r'\1""', text)
        (out_dir / "weapons" / f"{name}.json").write_text(patched, encoding="utf-8")
        print(f"{name}: {source.parent.parent.name}: camoViewModelMaterialOverride "
              f"{old.group(2)!r} -> ''" if old and old.group(2) else f"{name}: {source.parent.parent.name}: already empty")
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
