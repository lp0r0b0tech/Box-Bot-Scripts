#!/usr/bin/env python3
"""Write weapon/attachment JSON overrides that x64-zt (S1) can build into a loadable, pool-safe zone.

1. camoViewModelMaterialOverride.  weapon_def::parse reads WeaponDef.camoViewModelMaterialOverride from
the weapon JSON, but weapon_def::write never converts that pointer (only camoWorldModelMaterialOverride
is handled).  The raw in-process Material* is therefore copied into the zone, the engine's pointer loader
decodes it as an alias offset and the game crashes while loading the weapon.  Writing the field as ""
makes it a null pointer, which the engine accepts (stock weapons such as iw5_riotshieldt6_mp do the same).
A blank slot means no Mk2-Mk25 camo on the first-person model, so camo-fix-ff.py fills it in again in the built
fastfile (it copies each weapon's camoWorldModelMaterialOverride reference over, and stops at a weapon whose JSON
still holds a value here).

2. Tracers.  The engine's tracer pool holds only 32 assets, and the stock Zombies zones plus the map already
define 17-20 of them (every map brings 13-16 tracers of its own).  The 28 stock weapons name 15 different tracers;
a pack tracer that duplicates a map's tracer takes a second pool slot, so the pack can overflow the pool while
the map loads (the engine then stops with "Exceeded limit of N '<type>' assets").  Every non-empty
tracerType / signatureTracerType in the patched weapons, and in the attachments they carry, is therefore
pointed at defaulttracer, a stock asset that code_post_gfx_mp already defines.  Only the look of the bullet
tracers changes.  This is a precaution: the overflow that was actually seen came from the xanim pool (item 3).

3. Anim overrides.  The engine's xanim pool holds only 5,800 assets and the zones of a Zombies map fill an
estimated 4,400-4,850 of them (see pool-estimate.py).  The pack's 1,551 xanims included 709 that the 28 stock weapons
reference only through animOverrides (the replacement first-person animations a weapon plays when a given
attachment is fitted: the ADS-up/down of a scope, the switch into an alt-fire mode).  With them the game stopped
loading a map with "Exceeded limit of 5800" (the xanim pool).  Every weapon's animOverrides list is therefore cut
down to the entries of the attachments the shop really fits, which KEEP_ANIM_ATTACHMENTS lists per weapon: the optic
the shop fits to it (it takes the optic of its stock Zombies counterpart, see dlcws_upgrade_donor in the shop
script), plus what the game adds by itself (sensorheartbeatzm on the Ohm, akimboxmg on the dual XMG).  An entry
stays when it names at least one attachment and every attachment it names is in that set; everything else is
dropped (numAnimOverrides is the length of the list that remains, 0 for the other weapons, as for stock weapons
without overrides).  Emptying every list is the likely cause of the optics that did not work right and of the Ohm and
XMG alt-fire modes that did nothing in test 6 (the animations of both are stored only in these lists), so the
entries the shop can use are kept; the game has not confirmed that yet.  The 101 entries that stay use 109 xanims,
74 of them new to the pack (headroom: pool-estimate.py).

4. Marker weapons.  exo_zombies_linegun_support.gsc, the script that makes the Line Gun deal damage on the maps that do
not ship the Line Gun script, stays off unless the weapon iw5_dlcwscamo41_mp is registered next to iw5_linegunzm_mp and
iw5_linegundamagezm_mp (the earlier R41 pack defined it to show that its native Line Gun effects were loaded).  No stock
zone has that weapon and the scripts only check that the name is registered, so it is written here as a copy of the
damage weapon under the marker's name; every asset it needs is part of the pack already.  The shop reads the marker as
well: with it registered the shop knows that the camo materials of patch-camos.py are in the game, so the pack and the
shop script must always be installed together (older packs carry the marker as well, but not those materials).

5. Ammo.  The multiplayer weapons keep their multiplayer ammunition (the Thor 16 to start and 48 at most, the MAAWS a
single rocket, the 1911 28 and 42), well below the stock Zombies weapons of their class.  AMMO_TARGETS raises
startAmmo and maxAmmo to the values of the Zombies weapon that matches each one (named in the table), rounded up to
whole magazines.  Values are only ever raised and clipSize is not touched.  The EPM3 is left alone: it fires without
using ammunition (ammoPerShot 0, it overheats instead), like the Microwave.

6. Melee.  33 of the 35 stock Zombies guns in the dumped zones (iw5_*zm_mp, every class from pistols to launchers) carry
one melee data set: the tactical knife (knifeModel vm_mp_tactical_knife, worldKnifeModel npc_mp_tactical_knife), the
first-person animations vm_knife_melee_slice_l, vm_knife_melee_stab_l (also for a crouching victim, which five of the
guns leave empty), vm_exo_melee_hook_r and vm_exo_melee_uppercut_l, and the timers meleeChargeTime 1200, meleeDelay 80 and
meleeChargeDelay 100.  The multiplayer weapons of the pack still carry the multiplayer set (no knife model at all,
viewmodel_knife_melee_* / vm_exo_melee_punch, 1160/130/160), which may not display properly in Zombies: the knife swipe
without the exo suit would play with no knife in the hand, the punch with the suit the multiplayer animation.  That is a
candidate cause of the broken melee reported in test 7 with and without the suit (unconfirmed; the damage side is
weapon independent, see all_weapon_damage.gsc).  zm_melee_profile()
gives every multiplayer weapon the Zombies set, replacing only values that equal the multiplayer ones; the pistols also get
it in their left and right-handed animation sets, as the stock Zombies pistol does.  The Riot Shield (its own bash
animations), the stock Zombies guns and hasTransientModels (the models come from the pack and show correctly) stay as
they are.
The XMG, which the shop sells only as a dual-wield gun, is the other exception (test 8: no proper melee transition).  Its
animOverrides (item 3) force vm_exo_melee_punch into MELEE_ALT_STANDING and MELEE_ALT_CROUCHING of both hands, so the
hook and the uppercut of the profile never play in the dual state, and the tactical knife model would hang in the hand
during a punch.  It therefore keeps its multiplayer set, and hand_melee_anims() fills MELEE_SWIPE and MELEE_FATAL of its
left and right-handed animation sets, which the multiplayer weapon leaves empty, with the same punch, the way the stock
Zombies dual-wield gun iw5_sac3zm_mp fills them (with its knife swipe and stab).  Unconfirmed in game.

The originals in dump/ are not touched.  The script reads a ZoneTool CSV, resolves every
`weapon,<name>` through the CSV's `addpath` lines (first match wins, like ZoneTool) and writes the
patched copy to <out-dir>/weapons/<name>.json.  Attachments the weapons list that name a tracer are
written to <out-dir>/attachments/<name>.json (the folder is cleared first, so a rerun never leaves a stale
copy that would win the search order).  Put `addpath,<out-dir>` first in the CSV.

usage (from the workspace root):  patch-weapons.py zone_source/<pack>.csv dump/<out-dir>
"""
import json
import re
import sys
from pathlib import Path

CAMO_FIELD = re.compile(r'("camoViewModelMaterialOverride"\s*:\s*)"([^"]*)"')
ANIM_OVERRIDES = re.compile(r'("animOverrides"\s*:\s*)\[[^\]]*\]')
KNIFE_MODEL = re.compile(r'("knifeModel"\s*:\s*)"([^"]*)"')
WORLD_KNIFE_MODEL = re.compile(r'("worldKnifeModel"\s*:\s*)"[^"]*"')
WEAPON_TRACER = re.compile(r'("(?:tracerType|signatureTracerType)"\s*:\s*)"([^"]+)"')
ATTACHMENT_TRACER = re.compile(r'("name"\s*:\s*"tracerType"[^{}]*?"value"\s*:\s*)"([^"]+)"')
ATTACHMENT_LIST = re.compile(r'"attachments"\s*:\s*\[([^\]]*)\]')
DEFAULT_TRACER = "defaulttracer"
# Weapons that no stock zone defines, each written as a copy of the (already patched) weapon it maps to.
MARKER_WEAPONS = {"iw5_dlcwscamo41_mp": "iw5_linegundamagezm_mp"}
WEAPON_NAME = re.compile(r'("(?:szInternalName|baseAsset)"\s*:\s*)"[^"]*"')
AMMO_FIELDS = {"startAmmo": re.compile(r'("startAmmo"\s*:\s*)(-?\d+)'),
               "maxAmmo": re.compile(r'("maxAmmo"\s*:\s*)(-?\d+)')}

# animOverrides entries that stay in the zone: per weapon, the attachments an entry may name (see item 3).  The optic
# is the one the shop fits (dlcws_upgrade_donor); sensorheartbeatzm and akimboxmg are added by the game itself.
# Every weapon that is not listed keeps no entries.
KEEP_ANIM_ATTACHMENTS = {
    "iw5_dlcgun2zm_mp": {"sensorheartbeatzm", "opticstargetenhancer"},  # Ohm: alt-fire mode and its optic
    "iw5_exoxmg_mp": {"akimboxmg"},  # XMG (Dual): the alt-fire mode
    "iw5_dlcgun1zm_mp": {"opticseotech"},
    "iw5_tridentzm_mp": {"opticstargetenhancer"},
    "iw5_linegunzm_mp": {"opticstargetenhancer"},
    "iw5_microwavezm_mp": {"opticsreddot"},
    "iw5_m990_mp": {"opticsacog2"},
    "iw5_mors_mp": {"opticsacog2"},
    "iw5_dlcgun6loot5_mp": {"opticsacog2"},  # SVO
    "iw5_dlcgun23_mp": {"opticseotech"},  # M1 Garand
    "iw5_dlcgun33_mp": {"opticseotech"},  # Lever Action
    "iw5_dlcgun6_mp": {"opticseotech"},  # STG-44
    "iw5_dlcgun7loot0_mp": {"opticseotech"},  # AK-47
    "iw5_dlcgun7loot6_mp": {"opticseotech"},  # M16
    "iw5_pbw_mp": {"opticstargetenhancer"},  # MP443
    "iw5_dlcgun18_mp": {"opticsreddot"},  # MP40
    "iw5_dlcgun28_mp": {"opticsreddot"},  # Sten
    "iw5_dlcgun38_mp": {"opticsreddot"},  # Repulsor
    "iw5_epm3_mp": {"variablereddot"},
}

# (startAmmo, maxAmmo) of the multiplayer weapons that are raised (item 5), after the Zombies weapon named in the
# comment, in whole magazines.  startAmmo counts the magazine and the reserve, maxAmmo is the reserve alone.  Not
# listed: the M16 (already above), the SVO and the MORS (at the level of their Zombies weapon), the Riot Shield
# (no ammunition) and the EPM3 (overheats instead of using ammunition).
AMMO_TARGETS = {
    "iw5_thor_mp": (24, 48),  # gm6zm 24/48
    "iw5_dlcgun13_mp": (42, 70),  # 1911: titan45zm 40/65
    "iw5_pbw_mp": (48, 72),  # MP443: titan45zm 40/65
    "iw5_dlcgun7loot0_mp": (120, 210),  # AK-47: ak12zm 120/210
    "iw5_dlcgun6_mp": (120, 210),  # STG-44: ak12zm 120/210
    "iw5_dlcgun23_mp": (80, 120),  # M1 Garand: m182sprzm 80/120
    "iw5_dlcgun33_mp": (80, 120),  # Lever Action: m182sprzm 80/120
    "iw5_maaws_mp": (2, 10),  # mahemzm 2/10
    "iw5_microdronelauncher_mp": (12, 36),  # no Zombies counterpart: six magazines of reserve
    "iw5_stingerm7_mp": (8, 40),  # tridentzm 5/40
    "iw5_m990_mp": (24, 80),  # gm6zm 24/48
    "iw5_dlcgun18_mp": (128, 224),  # MP40: sn6zm 128/200, mp11zm 128/220
    "iw5_dlcgun28_mp": (128, 224),  # Sten: mp11zm 128/220
    "iw5_dlcgun38_mp": (140, 245),  # Repulsor: hmr9zm 140/200
    "iw5_exoxmg_mp": (400, 350),  # XMG (Dual): asawzm 200/350
}

# The melee data of the stock Zombies guns (item 6).  A weapon is a multiplayer weapon here when its knifeModel is one
# of MP_KNIFE_MODELS; only values that equal the multiplayer ones are replaced.
MP_KNIFE_MODELS = {"", "vm_mp_combat_knife"}
ZM_KNIFE_MODEL, ZM_WORLD_KNIFE_MODEL = "vm_mp_tactical_knife", "npc_mp_tactical_knife"
ZM_MELEE_ANIMS = {  # slot: ({multiplayer animation, ...}, Zombies animation)
    "MELEE_SWIPE": ({"vm_knife_melee_slice", "viewmodel_knife_melee_slice"}, "vm_knife_melee_slice_l"),
    "MELEE_FATAL": ({"vm_knife_melee_stab", "viewmodel_knife_melee_stab", "vm_knife_melee_slice"},
                    "vm_knife_melee_stab_l"),
    "MELEE_VICTIM_CROUCHING_FATAL": ({"vm_knife_melee_stab", "viewmodel_knife_melee_stab_crouched_hit"},
                                     "vm_knife_melee_stab_l"),
    "MELEE_ALT_STANDING": ({"vm_exo_melee_punch"}, "vm_exo_melee_hook_r"),
    "MELEE_ALT_CROUCHING": ({"vm_exo_melee_punch"}, "vm_exo_melee_uppercut_l"),
}
ZM_MELEE_TIMERS = {"meleeChargeTime": (1160, 1200), "meleeDelay": (130, 80), "meleeChargeDelay": (160, 100)}
# Weapons the shop sells only dual-wielded.  They keep their multiplayer melee data (a punch with both hands, no knife),
# and hand_melee_anims() fills the one gap of their left and right-handed animation sets (item 6).
DUAL_MELEE_WEAPONS = {"iw5_exoxmg_mp"}
HAND_MELEE_SLOTS = ("MELEE_SWIPE", "MELEE_FATAL")
# Weapons that keep their melee data: the Riot Shield bashes with its own animations and the dual XMG punches.
MELEE_PROFILE_SKIP = {"iw5_riotshieldt6_mp"} | DUAL_MELEE_WEAPONS
# weapClass of the pistols, whose left and right-handed animation sets follow the first-person set (as in the stock
# Zombies pistol iw5_dlcgun3zm_mp); the stock Zombies guns of the other classes keep multiplayer values there.
PISTOL_CLASS = 5


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


def filter_anim_overrides(name, text):
    """Keep the animOverrides entries that only name attachments of KEEP_ANIM_ATTACHMENTS[name].

    Returns the new text, the number of entries before and the number after.  The attachment indexes of an entry
    are 1-based positions in the weapon's attachments list, 0 meaning none."""
    if not ANIM_OVERRIDES.search(text):
        return text, 0, 0
    weapon = json.loads(text)
    entries = weapon.get("animOverrides", [])
    attachments = weapon.get("attachments", [])
    keep = KEEP_ANIM_ATTACHMENTS.get(name, set())
    if keep - set(attachments):
        sys.exit(f"{name}: KEEP_ANIM_ATTACHMENTS names {', '.join(sorted(keep - set(attachments)))}, "
                 f"which the weapon does not list as an attachment")
    kept = []
    for entry in entries:
        used = []
        for index in (entry["attachment1"], entry["attachment2"]):
            if not 0 <= index <= len(attachments):
                sys.exit(f"{name}: an animOverrides entry names attachment {index}, "
                         f"the weapon lists {len(attachments)}")
            if index:
                used.append(attachments[index - 1])
        if used and all(attachment in keep for attachment in used):
            kept.append(entry)
    if len(kept) == len(entries):
        return text, len(entries), len(kept)
    rewritten = json.dumps(kept, indent=4).replace("\n", "\n    ")
    return ANIM_OVERRIDES.sub(lambda m: m.group(1) + rewritten, text, count=1), len(entries), len(kept)


def raise_ammo(name, text):
    """Raise startAmmo and maxAmmo to AMMO_TARGETS[name] (never lower them); returns the new text and the changes."""
    changes = []
    for field, target in zip(AMMO_FIELDS, AMMO_TARGETS[name]):
        found = AMMO_FIELDS[field].findall(text)
        if len(found) != 1:
            sys.exit(f"{name}: expected one {field} in the weapon, found {len(found)}")
        old = int(found[0][1])
        if target > old:
            text = AMMO_FIELDS[field].sub(lambda m: f"{m.group(1)}{target}", text)
            changes.append(f"{field} {old} -> {target}")
    return text, changes


def edit_object(text, key, edit):
    """Apply edit(body) -> (body, count) to the body of the flat JSON object `key`; returns the new text and count."""
    found = re.search(r'"%s"\s*:\s*\{([^{}]*)\}' % re.escape(key), text)
    if found is None:
        return text, 0
    body, count = edit(found.group(1))
    return text[:found.start(1)] + body + text[found.end(1):], count


def zm_melee_profile(name, text):
    """Give a multiplayer weapon the melee data of the stock Zombies guns (item 6); returns the new text and the
    number of fields changed (0 for weapons that are left alone)."""
    knife = KNIFE_MODEL.search(text)
    if name in MELEE_PROFILE_SKIP or knife is None or knife.group(2) not in MP_KNIFE_MODELS:
        return text, 0
    pistol = json.loads(text).get("weapClass") == PISTOL_CLASS
    changed = 0

    def set_models(match):
        nonlocal changed
        changed += 1
        return f'{match.group(1)}"{ZM_KNIFE_MODEL}"'

    text = KNIFE_MODEL.sub(set_models, text)
    text = WORLD_KNIFE_MODEL.sub(lambda m: f'{m.group(1)}"{ZM_WORLD_KNIFE_MODEL}"', text)

    def anims(body):
        count = 0
        for slot, (old, new) in ZM_MELEE_ANIMS.items():
            def swap(match):
                nonlocal count
                if match.group(2) not in old:
                    return match.group(0)
                count += 1
                return f'{match.group(1)}"{new}"'
            body = re.sub(r'("%s"\s*:\s*)"([^"]*)"' % slot, swap, body)
        return body, count

    def timers(body):
        count = 0
        for field, (old, new) in ZM_MELEE_TIMERS.items():
            def swap(match):
                nonlocal count
                if int(match.group(2)) != old:
                    return match.group(0)
                count += 1
                return f"{match.group(1)}{new}"
            body = re.sub(r'("%s"\s*:\s*)(-?\d+)' % field, swap, body)
        return body, count

    sections = ["szXAnims"] + (["szXAnimsRightHanded", "szXAnimsLeftHanded"] if pistol else [])
    for key in sections:
        text, count = edit_object(text, key, anims)
        changed += count
    for key in ("stateTimers", "stateTimersAkimbo"):
        text, count = edit_object(text, key, timers)
        changed += count
    return text, changed


def hand_melee_anims(name, text):
    """Copy the first-person MELEE_SWIPE and MELEE_FATAL of a dual-wield weapon into its left and right-handed
    animation sets where they are empty (item 6); returns the new text and the number of entries filled."""
    if name not in DUAL_MELEE_WEAPONS:
        return text, 0
    first = json.loads(text)["szXAnims"]

    def fill(body):
        filled = 0
        for slot in HAND_MELEE_SLOTS:
            if first.get(slot):
                body, found = re.subn(r'("%s"\s*:\s*)""' % slot, lambda m: f'{m.group(1)}"{first[slot]}"', body)
                filled += found
        return body, filled

    changed = 0
    for key in ("szXAnimsRightHanded", "szXAnimsLeftHanded"):
        text, count = edit_object(text, key, fill)
        changed += count
    return text, changed


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

    unknown = sorted((set(KEEP_ANIM_ATTACHMENTS) | set(AMMO_TARGETS) | DUAL_MELEE_WEAPONS) - set(weapons))
    if unknown:
        sys.exit(f"{csv_path} does not list {', '.join(unknown)}, which KEEP_ANIM_ATTACHMENTS, AMMO_TARGETS or "
                 f"DUAL_MELEE_WEAPONS name")

    (out_dir / "weapons").mkdir(parents=True, exist_ok=True)
    (out_dir / "attachments").mkdir(parents=True, exist_ok=True)
    for stale in (out_dir / "attachments").glob("*.json"):
        stale.unlink()

    missing, attachments, kept_total = 0, set(), 0
    for name in [w for w in weapons if w not in MARKER_WEAPONS]:
        source = find(search, "weapons", name)
        if source is None:
            print(f"{name}: NOT FOUND in any addpath")
            missing += 1
            continue
        text = source.read_text(encoding="utf-8")
        camo = CAMO_FIELD.search(text)
        text = CAMO_FIELD.sub(r'\1""', text)
        text, tracers = retarget_tracers(WEAPON_TRACER, text)
        text, overrides, kept = filter_anim_overrides(name, text)
        text, melee = zm_melee_profile(name, text)
        text, hands = hand_melee_anims(name, text)
        ammo = []
        if name in AMMO_TARGETS:
            text, ammo = raise_ammo(name, text)
        weapon = json.loads(text)
        if len(weapon.get("animOverrides", [])) != kept:
            sys.exit(f"{name}: could not rewrite animOverrides")
        if name in AMMO_TARGETS and weapon["startAmmo"] > weapon["clipSize"] + weapon["maxAmmo"]:
            sys.exit(f"{name}: startAmmo {weapon['startAmmo']} is more than clipSize + maxAmmo")
        kept_total += kept
        (out_dir / "weapons" / f"{name}.json").write_text(text, encoding="utf-8")
        notes = []
        if camo and camo.group(2):
            notes.append(f"camoViewModelMaterialOverride {camo.group(2)!r} -> ''")
        if tracers:
            notes.append(f"tracers {', '.join(tracers)} -> {DEFAULT_TRACER}")
        if overrides:
            notes.append(f"animOverrides {overrides} -> {kept}")
        if melee:
            notes.append(f"melee profile ({melee} fields)")
        if hands:
            notes.append(f"per-hand melee animations ({hands} entries)")
        if ammo:
            notes.append(", ".join(ammo))
        print(f"{name}: {source.parent.parent.name}: {'; '.join(notes) or 'unchanged'}")
        for listed in ATTACHMENT_LIST.finditer(text):
            attachments.update(re.findall(r'"([^"]+)"', listed.group(1)))
    print(f"animOverrides entries kept in total: {kept_total}")

    for name in [w for w in weapons if w in MARKER_WEAPONS]:
        base = out_dir / "weapons" / f"{MARKER_WEAPONS[name]}.json"
        if not base.is_file():
            print(f"{name}: its base weapon {MARKER_WEAPONS[name]} is not in the recipe")
            missing += 1
            continue
        text = WEAPON_NAME.sub(lambda m: f'{m.group(1)}"{name}"', base.read_text(encoding="utf-8"))
        (out_dir / "weapons" / f"{name}.json").write_text(text, encoding="utf-8")
        print(f"{name}: copy of {MARKER_WEAPONS[name]}")

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
