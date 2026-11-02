#!/usr/bin/env python3
"""Make the Mk2 (camo 23, toxictiger) and Mk15 (camo 24, infected) camos show on the pack's weapons.

Why they fail: in mp/camotable.csv the retail rows 23 and 24 are "material camos": column 10 holds an index into
mp/camomaterialtable.csv, which names one finished material per weapon (m/ak12_toxictiger, m/ak12_infected, ...).
Of the 26 pack weapons that have a row there, 13 have blank cells (Thor, MAAWS, M990, Stinger M7, MP443, EPM3, MDL, MORS,
XMG, M1 Garand, Lever Action, Repulsor, Sten), 6 name materials that no dumped zone defines (1911, AK-47, M16, MP40,
STG-44, SVO) and only 7 (DLC Weapons I and III, Ohm, Blunderbuss, Line Gun, Microwave, Trident) name materials that
common_zm_mp or patch_common_zm_mp define, so on the other 19 the camo has nothing to show.  The image camos work on
every weapon: their rows (camo 25, "xom01", is the one in the zombies level order) name a camo material in column 8, a
plain material whose first texture is the camo pattern, and leave column 10 empty.

This script gives rows 23 and 24 the image form, using the retail pattern images camo_xom1_toxic_tiger_col and
camo_xom1_infected_col (both are in common_zm_mp, so they are loaded on every zombies map):
  <out-dir>/mp/camotable.csv       a copy of the retail table with only rows 23 and 24 changed; the recipe ships it as
                                   `stringtable,mp/camotable.csv`, meant to override the retail table by name (not yet
                                   confirmed in the game: the shop's dlcws_runtime_status.log shows what it reads back)
  <out-dir>/materials/<name>.json  one camo material per pattern, a copy of the retail camo_xom1_01 with its pattern image
                                   swapped (the recipe lists them as `material,<name>`)
  <out-dir>/techsets/{state,constantbuffer}/<techset>/<name>.*
                                   the copies of camo_xom1_01's state files that ZoneTool reads for a material of that name
The look is the plain pattern; the retail glow (the per-weapon "ems" maps) is not reproduced.

Needs the dumps of eng_patch_code_post_gfx_mp (stringtable) and common_zm_mp (materials); usage from the workspace root:
  patch-camos.py [dump/exo_patch]
"""
import shutil
import sys
from pathlib import Path

STOCK_TABLE = Path("dump/eng_patch_code_post_gfx_mp/mp/camotable.csv")
TEMPLATE = "camo_xom1_01"
TEMPLATE_IMAGE = "camo_zombies_01"
TEMPLATE_DIR = Path("dump/common_zm_mp")

# camo index -> (name in the table, camo material and pattern image)
CAMOS = {
    23: ("toxictiger", "camo_xom1_toxic_tiger_col"),
    24: ("infected", "camo_xom1_infected_col"),
}
NAME_COL, MATERIAL_COL, FLAG_COL, LAYER_COL, EXTRA_COL = 1, 8, 9, 10, 11


def patch_table(out_dir):
    raw = STOCK_TABLE.read_bytes().decode("utf-8")
    lines = raw.splitlines(keepends=True)
    for index, (name, material) in CAMOS.items():
        row = lines[index].rstrip("\r\n").split(",")
        if row[0] != str(index) or row[NAME_COL] != name or row[MATERIAL_COL] or not row[LAYER_COL]:
            sys.exit(f"{STOCK_TABLE}: row {index} is not the retail {name} row: {lines[index].strip()}")
        row[MATERIAL_COL], row[FLAG_COL], row[LAYER_COL], row[EXTRA_COL] = material, "0", "", "1"
        lines[index] = ",".join(row) + lines[index][len(lines[index].rstrip("\r\n")):]
    target = out_dir / "mp" / "camotable.csv"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes("".join(lines).encode("utf-8"))
    print(f"{target}: rows {', '.join(map(str, CAMOS))} now use camo materials "
          f"{', '.join(material for _, material in CAMOS.values())}")


def write_materials(out_dir):
    source = TEMPLATE_DIR / "materials" / f"{TEMPLATE}.json"
    text = source.read_text(encoding="utf-8")
    old_name, old_image = f'"name": "{TEMPLATE}"', f'"image": "{TEMPLATE_IMAGE}"'
    if text.count(old_name) != 1 or text.count(old_image) != 1:
        sys.exit(f"{source}: not the expected {TEMPLATE} material")
    techset = next(line.split('"')[3] for line in text.splitlines() if '"techniqueSet->name"' in line)
    (out_dir / "materials").mkdir(parents=True, exist_ok=True)
    for _, material in CAMOS.values():
        (out_dir / "materials" / f"{material}.json").write_text(
            text.replace(old_name, f'"name": "{material}"').replace(old_image, f'"image": "{material}"'),
            encoding="utf-8")
        for folder, extensions in (("state", ("stateinfo", "statebits", "statebitsmap")), ("constantbuffer", ("cbi", "cbt"))):
            target_dir = out_dir / "techsets" / folder / techset
            target_dir.mkdir(parents=True, exist_ok=True)
            for ext in extensions:
                shutil.copyfile(TEMPLATE_DIR / "techsets" / folder / techset / f"{TEMPLATE}.{ext}",
                                target_dir / f"{material}.{ext}")
        print(f"{out_dir / 'materials' / (material + '.json')}: {TEMPLATE} with pattern image {material}")


def main(argv):
    out_dir = Path(argv[1]) if len(argv) > 1 else Path("dump/exo_patch")
    patch_table(out_dir)
    write_materials(out_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
