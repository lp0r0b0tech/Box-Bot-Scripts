#!/usr/bin/env python3
"""Write sound alias overrides that keep the pack's loaded_sound count under the engine's pool limit.

The engine's loaded_sound pool holds 7,000 assets.  The stock zones of the Descent map (mp_zombie_h2o) already fill an
estimated 6,836 of them, and every loaded sound of the pack that the base zones do not define takes one more slot, even
when the map's own zone defines the same sound (see pool-estimate.py).  The pack's 189 such sounds (in the build of test 7)
therefore overflowed the pool on that one map, 7,025 of 7,000 by the estimate.  This script cuts the count with three
kinds of override, each written to <out-dir>/sounds/<alias>.json (dump/exo_patch comes first in the recipe's search
order, so the override wins over the stock alias).  With them the pack adds 131 and the map reaches 6,967 of 7,000:

1. FIRST_VARIANTS.  An alias that holds several takes of one sound (the Line Gun's chirps, coil buzzes and zaps, the Ohm's
laser, the M1 Irons' twang, the M1 Garand's ping, the Microwave's flesh explosion) keeps its first entries only.  The game
then plays the same take every time instead of picking one at random.  Reload and foley sounds are one file per alias and
are not touched.

2. DROP_FILES.  An alias loses the entries whose sound file matches a pattern: the Line Gun's beam spark keeps the ten
takes that the base zones define and drops the nine general/electrical/spark_zap_NN takes that only the pack carries.

3. REUSE_FILES.  An alias plays the sound file of another alias instead of its own, keeping its own volume, distance and
pitch settings.  The M1 Irons (dual wield) ship one reload/foley file per hand; both hands now use the right hand's.

The originals in dump/ are not touched.  The script reads a ZoneTool CSV only for its `addpath` lines (first match wins,
like ZoneTool) and clears <out-dir>/sounds first, so a rerun never leaves a stale override that would win the search order.
Put `addpath,<out-dir>` first in the CSV.  The PCM copies of the loaded sounds that stay come from flac-to-wav.py.

usage (from the workspace root):  patch-sounds.py zone_source/<pack>.csv dump/<out-dir>
"""
import copy
import json
import re
import sys
from pathlib import Path

# alias -> number of entries (takes) that stay; groups of aliases that share their files must be cut together
FIRST_VARIANTS = {
    "wpn_linegun_chirp": 1, "wpn_linegun_beam_chirp": 1,
    "wpn_linegun_coil_buzz": 1,
    "wpn_linegun_zap_plr": 1,
    "wpn_linegun_exp": 1,
    "wpn_linegun_spark": 1,
    "wpn_m1irons_tail_twang": 1,
    "wpn_m1garand_ping": 1,
    "wpn_ohm_lzr": 1, "wpn_ohm_lzr_npc": 1, "wpn_ohmsg_lsr": 1, "wpn_ohmsg_lzr_npc": 1,
    "wpn_ohm_xform_to_sg_main": 1,
    "wpn_trident_spark_npc": 1, "wpn_trident_spark_plr": 1,
    "melee_knife_stab": 1,
    # Microwave death sounds (exo_zombies_microwave_support.gsc): five takes each, FLAC, defined only by mp_zombie_brg
    "npc_mwave_flesh_expl_front": 1, "npc_mwave_flesh_expl_rear": 1,
}

# alias -> regular expression of the sound file names whose entries are dropped
DROP_FILES = {
    "wpn_linegun_beam_spark": r"^general/electrical/spark_zap_",
}

# alias -> alias whose sound files it plays instead (entry i takes the file of entry i of the target, wrapping around)
REUSE_FILES = {f"wpn_m1_left_{suffix}": f"wpn_m1_right_{suffix}" for suffix in (
    "empty_charge", "empty_foley_start", "empty_magout", "holster_decock", "holster_foley_start", "holster_whooshes",
    "pull_foley_start", "pull_grab", "pull_whooshes", "tac_charge", "tac_foley_start", "tac_magout")}


def csv_lines(path):
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line and not line.startswith(("#", "//")):
            yield [part.strip() for part in line.split(",")]


def find(search, alias):
    return next((p / "sounds" / f"{alias}.json" for p in search
                 if (p / "sounds" / f"{alias}.json").is_file()), None)


def file_name(entry):
    return (entry.get("soundfile") or {}).get("name") or ""


def load(search, alias):
    source = find(search, alias)
    if source is None:
        sys.exit(f"{alias}: NOT FOUND in any addpath")
    data = json.loads(source.read_text(encoding="utf-8"))
    if data.get("contextList"):
        sys.exit(f"{alias}: has a contextList, which this script does not rewrite")
    if data["count"] != len(data["head"]):
        sys.exit(f"{alias}: count {data['count']} is not the {len(data['head'])} entries it lists")
    return data, source


def main(argv):
    if len(argv) != 3:
        sys.exit(__doc__)
    csv_path, out_dir = Path(argv[1]), Path(argv[2])
    search = []
    for fields in csv_lines(csv_path):
        if fields[0] == "addpath" and len(fields) > 1:
            path = Path(fields[1].replace("\\", "/"))
            if path.resolve() != out_dir.resolve():
                search.append(path)
    (out_dir / "sounds").mkdir(parents=True, exist_ok=True)
    for stale in (out_dir / "sounds").glob("*.json"):
        stale.unlink()

    written = {}
    for alias, keep in FIRST_VARIANTS.items():
        data, source = load(search, alias)
        before = [file_name(e) for e in data["head"]]
        if not 1 <= keep <= len(before):
            sys.exit(f"{alias}: cannot keep {keep} of {len(before)} entries")
        data["head"] = data["head"][:keep]
        written[alias] = (data, source, before)
    for alias, pattern in DROP_FILES.items():
        data, source = load(search, alias)
        before = [file_name(e) for e in data["head"]]
        data["head"] = [e for e in data["head"] if not re.search(pattern, file_name(e))]
        if not data["head"]:
            sys.exit(f"{alias}: every entry matches {pattern}")
        written[alias] = (data, source, before)
    for alias, target in REUSE_FILES.items():
        data, source = load(search, alias)
        donor, _ = load(search, target)
        before = [file_name(e) for e in data["head"]]
        if not donor["head"] or any((e.get("soundfile") or {}).get("type") != 1 for e in donor["head"]):
            sys.exit(f"{alias}: {target} does not hold loaded sounds only")
        for i, entry in enumerate(data["head"]):
            entry["soundfile"] = copy.deepcopy(donor["head"][i % len(donor["head"])]["soundfile"])
        written[alias] = (data, source, before)

    for alias, (data, source, before) in sorted(written.items()):
        data["count"] = len(data["head"])
        (out_dir / "sounds" / f"{alias}.json").write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8")
        after = [file_name(e) for e in data["head"]]
        print(f"{alias}: {source.parent.parent.name}: {len(before)} -> {len(after)} entries"
              f"{'' if after == before[:len(after)] else ' (files ' + ', '.join(sorted(set(after))) + ')'}")
    print(f"{len(written)} alias overrides written to {out_dir / 'sounds'}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
