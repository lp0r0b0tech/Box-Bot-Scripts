#!/usr/bin/env python3
"""Check that the weapons of a pack recipe find every model, surface, material, techset and image they need.

When ZoneTool builds a pack and cannot find a dumped xmodel, it copies whatever the running engine holds under that
name and prints no warning.  For models that live in unloaded transient zones (the multiplayer weapons' viewmodels
and worldmodels) that copy is a placeholder, which is a red box in game, so a clean build can still be wrong.  This
script finds those holes before the build.  It reads the recipe's addpath lines (the dump directories, in search
order), takes every weapon's model fields (gunModel, worldModel, handModel, stowOffsetModel, ...) and follows them:

  xmodel/<name>.xmb      -> its composite models (vm_*/npc_* names), its surfaces (xsurface/<hash>_<hash>_<lod>.xsb)
                            and its materials (names with a "/" or an "mtl_" prefix)
  materials/<name>.json  -> its techset (techsets/<name>.techset) and its images (images/<name>.*)

The .xmb files are a binary format, so their references are found by reading the strings in them; a name that looks
like a model or material but is no file shows up under MISSING, which is also what a real hole looks like.

Only the weapons' models are followed.  The recipe's other asset lines (effects, sounds and what they reference, such as
the Line Gun's beam and explosion effects) and animations are not checked here; the build log shows a hole in those.

Usage (from the workspace root):  model-closure.py [recipe.csv] [dump-root] [-v]
Defaults: zone_source/exo_weapons_all.csv and dump.  -v lists every asset.  Exit status 1 if anything is missing.
"""
import collections
import json
import re
import sys
from pathlib import Path

# What a name that no search directory holds would look like, for each kind: this is how a hole is told from a
# bone name or other string of the .xmb (a name that does resolve to a file never needs these patterns).
HASH_SURF = re.compile(r"^[0-9a-f]{8}_[0-9a-f]{8}_\d{3}$")
LOD_SURF = re.compile(r"^[a-z0-9_]+_lod[a-z]*\d{3}$")
MATERIAL = re.compile(r"^(?:(?:m|mc|mce|me|ml|mlc|ms|msc|mv|mvc|wc)/)?mtl_[a-z0-9_]+$")
SUBMODEL = re.compile(r"^(?:vm|npc)_[a-z0-9_]+$")
STRINGS = re.compile(rb"[\x21-\x7e]{3,}")
KINDS = (("xmodelsurfs", "xsurface"), ("material", "materials"), ("xmodel", "xmodel"))


def read_recipe(recipe, root):
    dirs, weapons = [], []
    for line in recipe.read_text(encoding="utf-8").splitlines():
        kind, _, arg = line.strip().partition(",")
        if kind == "addpath":
            dirs.append(root / arg.replace("\\", "/").split("/")[-1])
        elif kind == "weapon":
            weapons.append(arg)
    return dirs, weapons


def asset_fields(obj, suffixes, key=""):
    """The string values of the fields whose name ends in one of the suffixes, wherever they sit in the JSON."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            yield from asset_fields(v, suffixes, k)
    elif isinstance(obj, list):
        for v in obj:
            yield from asset_fields(v, suffixes, key)
    elif isinstance(obj, str) and obj and key.endswith(suffixes):
        yield obj


class Finder:
    """Finds the file of an asset by name in the search directories; the first directory that has it wins."""

    def __init__(self, dirs):
        self.dirs = dirs
        self.index = {}

    def names(self, d, sub):
        key = (d, sub)
        if key not in self.index:
            base = d / sub
            files = base.rglob("*") if base.is_dir() else ()
            self.index[key] = {p.relative_to(base).as_posix().rsplit(".", 1)[0]: p for p in files if p.is_file()}
        return self.index[key]

    def find(self, sub, name):
        for d in self.dirs:
            p = self.names(d, sub).get(name)
            if p:
                return d, p
        return None, None


def main(argv):
    args = [a for a in argv[1:] if a != "-v"]
    verbose = "-v" in argv
    recipe = Path(args[0] if args else "zone_source/exo_weapons_all.csv")
    root = Path(args[1] if len(args) > 1 else "dump")
    dirs, weapons = read_recipe(recipe, root)
    finder = Finder(dirs)
    origin = collections.defaultdict(lambda: collections.defaultdict(set))  # kind -> dir -> names
    missing = collections.defaultdict(lambda: collections.defaultdict(set))  # weapon -> kind -> names
    seen = {"xmodel": set(), "material": set()}

    def walk_material(weapon, name):
        if name in seen["material"]:
            return
        seen["material"].add(name)
        d, p = finder.find("materials", name)
        if p is None:
            missing[weapon]["material"].add(name)
            return
        origin["material"][d.name].add(name)
        try:
            info = json.loads(p.read_text(encoding="utf-8"))
        except ValueError as err:
            missing[weapon]["material json"].add(f"{name} ({err})")
            return
        tech = info.get("techniqueSet->name")
        if tech:
            td, tp = finder.find("techsets", tech)
            if tp is None:
                missing[weapon]["techset"].add(tech)
            else:
                origin["techset"][td.name].add(tech)
        for tex in info.get("textureTable", []):
            image = tex.get("image")
            if image:
                idir, ip = finder.find("images", image)
                if ip is None:
                    missing[weapon]["image"].add(image)
                else:
                    origin["image"][idir.name].add(image)

    def walk_model(weapon, name):
        if name in seen["xmodel"]:
            return
        seen["xmodel"].add(name)
        d, p = finder.find("xmodel", name)
        if p is None:
            missing[weapon]["xmodel"].add(name)
            return
        origin["xmodel"][d.name].add(name)
        for s in sorted({m.decode() for m in STRINGS.findall(p.read_bytes())} - {name}):
            for kind, sub in KINDS:
                sd, sp = finder.find(sub, s)
                if sp is not None:
                    break
            else:
                guess = ("xmodelsurfs" if HASH_SURF.match(s) or LOD_SURF.match(s) else
                         "material" if MATERIAL.match(s) else "xmodel" if SUBMODEL.match(s) else None)
                if guess:
                    missing[weapon][guess].add(s)
                continue
            if kind == "xmodelsurfs":
                origin[kind][sd.name].add(s)
            elif kind == "material":
                walk_material(weapon, s)
            else:
                walk_model(weapon, s)

    bad = 0
    for weapon in weapons:
        _, wp = finder.find("weapons", weapon)
        if wp is None:
            print(f"{weapon}: weapon JSON not found")
            bad += 1
            continue
        seen["xmodel"].clear()
        seen["material"].clear()
        info = json.loads(wp.read_text(encoding="utf-8"))
        roots = set(asset_fields(info, ("Model", "Models")))
        for name in sorted(set(asset_fields(info, ("MaterialOverride",)))):
            walk_material(weapon, name)
        for name in sorted(set(info.get("attachments") or [])):
            if not name:
                continue
            ad, ap = finder.find("attachments", name)
            if ap is None:
                missing[weapon]["attachment"].add(name)
                continue
            origin["attachment"][ad.name].add(name)
            roots |= set(asset_fields(json.loads(ap.read_text(encoding="utf-8")), ("Model", "Models")))
        for model in sorted(roots):
            walk_model(weapon, model)
        holes = {k: sorted(v) for k, v in missing[weapon].items() if v}
        status = "OK" if not holes else "MISSING " + "; ".join(f"{k}: {' '.join(v)}" for k, v in holes.items())
        print(f"{weapon}: {len(roots)} model fields, {sum(map(len, seen.values()))} models+materials -> {status}")
        bad += bool(holes)
    print(f"\nasset origin (kind: directory=count), {len(weapons)} weapons, {len(dirs)} search dirs:")
    for kind in ("attachment", "xmodel", "xmodelsurfs", "material", "techset", "image"):
        parts = ", ".join(f"{d}={len(n)}" for d, n in sorted(origin[kind].items(), key=lambda kv: -len(kv[1])))
        print(f"  {kind}: {sum(len(n) for n in origin[kind].values())} found ({parts})")
        if verbose:
            for d, names in origin[kind].items():
                print(f"    {d}: {' '.join(sorted(names))}")
    print(f"{bad} of {len(weapons)} weapons have missing assets")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
