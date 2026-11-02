#!/usr/bin/env python3
"""Give the Mk2 (camo 23, "toxictiger") and Mk15 (camo 24, "infected") camos to every weapon of the pack.

How the retail game applies them: rows 23 and 24 of mp/camotable.csv are "material camos".  Column 10 of such a row is
an index into mp/camomaterialtable.csv, which names one finished material per weapon (m/ak12_toxictiger,
m/ak12_infected, ...).  The four Exo camos 19 to 22 ("camo01" to "camo04") use the same table with the materials
m/<weapon>_reptile, _electricity, _tech and _lava.  The engine swaps the weapon model's base material for the named
one; the camo is gone when the cell is blank or no loaded zone defines the named material.

What the 26 pack weapons that have a row in that table get from the retail Zombies zones:
  - 7 are complete (DLC Weapon I, Ohm, DLC Weapon III, Blunderbuss, Line Gun, Microwave, Trident): common_zm_mp and
    patch_common_zm_mp define their toxictiger and infected materials, nothing to do;
  - 6 name materials that no zone defines (class B: 1911, AK-47, M16, MP40, STG-44, SVO);
  - 13 have blank toxictiger and infected cells (class C: Thor, MP443, EPM3, Lever Action, M1 Garand, MAAWS, MDL, M990,
    Repulsor, Stinger M7, Sten, MORS, XMG).
The Riot Shield has no row at all, so it cannot carry a camo.

The pack cannot replace the tables: both are assets of a startup zone and the engine keeps the first copy of an asset
name that is loaded twice, so a copy in the pack is dropped (the first attempt, a pack copy of mp/camotable.csv, did
nothing).  What a pack can add are materials, and the engine finds a material by the name the table gives it:
  class B  the pack defines m/<weapon>_toxictiger and m/<weapon>_infected, the names the table already has;
  class C  the pack defines the materials of the camo01 row (19, table column 1, m/<weapon>_reptile) and of the camo04
           row (22, column 4, m/<weapon>_lava), which only the multiplayer zones define, and the shop script gives
           these weapons camo 19 for Mk2 and camo 22 for Mk15 (dlcws_camo_for_level in
           exo_zombies_dlc_weapon_shop.gsc).

Each new material is the multiplayer material m/<weapon>_reptile (from patch_common_mp) with the three camo decal
textures (color, normal, specular) replaced by the ones the retail toxic tiger or infected material uses.  The decal
mask and glow map of the weapon, the flow maps, the techset and all constants stay the donor's, so the pattern and the
animated flow are the retail ones on the donor's layout, with the retail per-weapon glow map missing (those exist only
for the retail weapons).  The retail infected material also uses another techset and a dimmer glow; that is not
reproduced, because the constant buffer file (.cbt) of a material holds its constants at unaligned offsets and cannot be
regenerated.  Instead each material takes the donor's state files verbatim (the state files are byte-identical across
these materials; the constant buffer files differ only in per-material filler and in the constants, which are the
donor's own): techsets/state/<techset>/<name>.{stateinfo,statebits,statebitsmap} and
techsets/constantbuffer/<techset>/<name>.{cbi,cbt}.

The self test rebuilds the retail m/ak12_toxictiger and m/ak12_infected from m/ak12_reptile and checks that the three
decal textures come out as in the retail materials and that nothing else but the glow map, the mask, the techset and two
constants differs.

Writes into <out-dir> (default dump/exo_patch): materials/m/<name>.json and the state files, removes the files of the
earlier attempt, and lists the `material,<name>` recipe lines that are missing from zone_source/exo_weapons_all.csv.
Needs the dumps of eng_patch_code_post_gfx_mp (tables), patch_common_mp (donors), common_zm_mp (images, self test).
Usage, from the workspace root:  patch-camos.py [dump/exo_patch]
"""
import copy
import csv
import json
import shutil
import sys
from pathlib import Path

DUMP = Path("dump")
RECIPE = Path("zone_source/exo_weapons_all.csv")
TABLE_DIR = DUMP / "eng_patch_code_post_gfx_mp" / "mp"
DONOR_ZONE = "patch_common_mp"
RETAIL_ZONE = "common_zm_mp"

# typeHash of the texture slots that make up a camo
DECAL_COLOR, DECAL_NORMAL, DECAL_SPEC = 659983135, 1518176625, 3426233914
GLOW, MASK = 878789447, 3135443286
LOOKS = {
    "toxictiger": {DECAL_COLOR: "camo_xom1_toxic_tiger_col", DECAL_NORMAL: "rec_telescope_02_nml",
                   DECAL_SPEC: "~camo_xom1_toxic_tiger_spc-rg~bcddc083"},
    "infected": {DECAL_COLOR: "camo_xom1_infected_col", DECAL_NORMAL: "camo_xom1_infected_nml",
                 DECAL_SPEC: "~camo_xom1_infected_spc-rgb&c~29b50c61"},
}
# camo index (row of mp/camotable.csv) -> column of mp/camomaterialtable.csv (column 10 of the row, plus one)
ROW_COLUMN = {19: 1, 22: 4, 23: 5, 24: 6}
STATE_FILES = (("state", ("stateinfo", "statebits", "statebitsmap")), ("constantbuffer", ("cbi", "cbt")))

# key in camomaterialtable.csv -> material name stem, for the weapons the shop sells
CLASS_B = {"iw5_dlcgun13": "m1911", "iw5_dlcgun7loot0": "ak47", "iw5_dlcgun7loot6": "m16",
           "iw5_dlcgun18": "ger_mp40_dlc", "iw5_dlcgun6": "stg44", "iw5_dlcgun6loot5": "dragunov_dlc"}
CLASS_C = {"iw5_thor": "thor", "iw5_pbw": "mp443", "iw5_epm3": "epm3", "iw5_dlcgun33": "winchester",
           "iw5_dlcgun23": "m1garand", "iw5_maaws": "maaws", "iw5_microdronelauncher": "mdl", "iw5_m990": "m990",
           "iw5_dlcgun38": "fm4", "iw5_stingerm7": "stingerm7_top", "iw5_dlcgun28": "eng_sten_dlc", "iw5_mors": "mors",
           "iw5_exoxmg": "exo_weapon_bracer"}

# what the first attempt wrote (a table override and two flat camo materials), relative to the out dir
STALE_FILES = ["mp/camotable.csv", "materials/camo_xom1_toxic_tiger_col.json", "materials/camo_xom1_infected_col.json"]
STALE_GLOBS = ["techsets/*/*/camo_xom1_*"]


def die(message):
    sys.exit(f"patch-camos.py: {message}")


def load_material(zone, name):
    path = DUMP / zone / "materials" / f"{name}.json"
    if not path.is_file():
        die(f"{path} is missing")
    return json.loads(path.read_text(encoding="utf-8"))


def dump_material(material):
    return json.dumps(material, indent=4, ensure_ascii=False)


def derive(donor, new_name, look):
    """The donor with the decal textures of `look` and the name `new_name`."""
    material = copy.deepcopy(donor)
    material["name"] = new_name
    seen = set()
    for texture in material["textureTable"]:
        image = LOOKS[look].get(texture["typeHash"])
        if image is not None:
            texture["image"] = image
            seen.add(texture["typeHash"])
    if seen != set(LOOKS[look]):
        die(f"{donor['name']} lacks a decal slot (found {sorted(seen)})")
    return material


def differences(a, b):
    """Human readable differences between two material dicts."""
    found = []
    for key in sorted(set(a) | set(b)):
        if key not in ("textureTable", "constantTable") and a.get(key) != b.get(key):
            found.append(("header", key, a.get(key), b.get(key)))
    ta = {t["typeHash"]: t for t in a["textureTable"]}
    tb = {t["typeHash"]: t for t in b["textureTable"]}
    for type_hash in sorted(set(ta) | set(tb)):
        if ta.get(type_hash) != tb.get(type_hash):
            found.append(("texture", type_hash, ta.get(type_hash, {}).get("image"), tb.get(type_hash, {}).get("image")))
    ca = {c["nameHash"]: c for c in a["constantTable"]}
    cb = {c["nameHash"]: c for c in b["constantTable"]}
    for name_hash in sorted(set(ca) | set(cb)):
        if ca.get(name_hash) != cb.get(name_hash):
            found.append(("constant", name_hash, ca.get(name_hash, {}).get("literal"), cb.get(name_hash, {}).get("literal")))
    return found


def self_test():
    donor = load_material(DONOR_ZONE, "m/ak12_reptile")
    allowed = {("texture", GLOW), ("texture", MASK), ("header", "techniqueSet->name"),
               ("constant", 3470264323), ("constant", 2025487071)}
    for look in LOOKS:
        retail = load_material(RETAIL_ZONE, f"m/ak12_{look}")
        found = differences(derive(donor, f"m/ak12_{look}", look), retail)
        unexpected = [d for d in found if d[:2] not in allowed]
        print(f"self test m/ak12_{look}: differs from the retail material in "
              f"{', '.join(f'{kind} {key}' for kind, key, _, _ in found) or 'nothing'}")
        if unexpected:
            die(f"self test failed for {look}: {unexpected}")


def read_tables():
    camotable = list(csv.reader((TABLE_DIR / "camotable.csv").read_text(encoding="utf-8-sig").splitlines()))
    materials = {row[0]: row for row in csv.reader((TABLE_DIR / "camomaterialtable.csv").read_text(encoding="utf-8-sig").splitlines()) if row}
    for index, column in ROW_COLUMN.items():
        if int(camotable[index][10]) + 1 != column:
            die(f"camotable.csv row {index} has column 10 = {camotable[index][10]}, expected {column - 1}")
    return materials


def plan(materials):
    """[(table key, class, stem, {look: material name})], checked against the retail table."""
    rows = []
    for key, stem in CLASS_B.items():
        row = materials[key]
        names = {"toxictiger": f"m/{stem}_toxictiger", "infected": f"m/{stem}_infected"}
        if (row[ROW_COLUMN[23]], row[ROW_COLUMN[24]]) != (names["toxictiger"], names["infected"]):
            die(f"{key}: the table does not name {names} in columns 5 and 6: {row}")
        rows.append((key, "B", stem, names))
    for key, stem in CLASS_C.items():
        row = materials[key]
        names = {"toxictiger": f"m/{stem}_reptile", "infected": f"m/{stem}_lava"}
        if row[ROW_COLUMN[23]] or row[ROW_COLUMN[24]]:
            die(f"{key}: expected blank toxictiger and infected cells: {row}")
        if (row[ROW_COLUMN[19]], row[ROW_COLUMN[22]]) != (names["toxictiger"], names["infected"]):
            die(f"{key}: the table does not name {names} in columns 1 and 4: {row}")
        rows.append((key, "C", stem, names))
    return rows


def addpaths():
    dirs = []
    for line in RECIPE.read_text(encoding="utf-8").splitlines():
        if line.startswith("addpath,"):
            dirs.append(Path(line.split(",", 1)[1].strip().replace("\\", "/")))
    return dirs


def write_files(out_dir, donor_name, material):
    path = out_dir / "materials" / f"{material['name']}.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(dump_material(material), encoding="utf-8")
    techset = material["techniqueSet->name"]
    for folder, extensions in STATE_FILES:
        for extension in extensions:
            source = DUMP / DONOR_ZONE / "techsets" / folder / techset / f"{donor_name}.{extension}"
            target = out_dir / "techsets" / folder / techset / f"{material['name']}.{extension}"
            if not source.is_file():
                die(f"{source} is missing")
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)


def remove_stale(out_dir):
    for relative in STALE_FILES:
        target = out_dir / relative
        if target.is_file():
            target.unlink()
            print(f"removed {target}")
    for pattern in STALE_GLOBS:
        for target in sorted(out_dir.glob(pattern)):
            if target.is_file():
                target.unlink()
                print(f"removed {target}")
    for folder in sorted((p for p in out_dir.rglob("*") if p.is_dir()), key=lambda p: len(p.parts), reverse=True):
        if not any(folder.iterdir()):
            folder.rmdir()


def main(argv):
    out_dir = Path(argv[1]) if len(argv) > 1 else DUMP / "exo_patch"
    self_test()
    rows = plan(read_tables())
    search = addpaths()
    images = {}
    names = []
    for key, klass, stem, targets in rows:
        donor_name = f"m/{stem}_reptile"
        donor = load_material(DONOR_ZONE, donor_name)
        for look, name in targets.items():
            material = derive(donor, name, look)
            write_files(out_dir, donor_name, material)
            names.append(name)
            for texture in material["textureTable"]:
                images.setdefault(texture["image"], None)
        print(f"{key:24s} class {klass}  {donor['techniqueSet->name'][-34:]:34s} -> {', '.join(targets.values())}")
    remove_stale(out_dir)

    total = 0
    missing = []
    for image in sorted(images):
        found = next((d / "images" / f"{image}.s1Image" for d in search if (d / "images" / f"{image}.s1Image").is_file()), None)
        if found is None:
            missing.append(image)
        else:
            images[image] = found.stat().st_size
            total += images[image]
    print(f"{len(names)} materials, {len(images)} distinct images ({total / 1e6:.1f} MB if none were in the pack yet)")
    if missing:
        die("images that no recipe directory has: " + ", ".join(missing))

    recipe = {line.strip() for line in RECIPE.read_text(encoding="utf-8").splitlines()}
    absent = [f"material,{name}" for name in names if f"material,{name}" not in recipe]
    stale = [line for line in ("stringtable,mp/camotable.csv", "material,camo_xom1_toxic_tiger_col",
                               "material,camo_xom1_infected_col") if line in recipe]
    if absent:
        print(f"recipe lines to add to {RECIPE}:")
        print("\n".join(absent))
    if stale:
        print(f"recipe lines of the first attempt to remove from {RECIPE}: " + ", ".join(stale))
    if not absent and not stale:
        print(f"{RECIPE} lists all {len(names)} materials")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
