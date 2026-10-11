put scripts folder into s1 folder
put bots.txt in s1 folder 2

## Single-weapon diagnostic (multiplayer MORS)

Use `scripts/zm/exo_zombies_single_weapon_test.gsc` in a **private test match**.
Install it in the same auto-loaded directory as an already-working Zombies
script on your client (the repository convention is `s1/scripts/zm/`;
CB launcher layouts may differ). Restart the map after installation.
Temporarily move other custom scripts, including the shared MP printer script,
out of the loader directory so unrelated errors cannot interfere with the test.

Set `scr_zm_single_weapon_test_enabled 1` before loading the map (default `1`);
set it to `0` to disable. Supports Outbreak (`mp_zombie_lab`), Infection
(`mp_zombie_brg`), Carrier (`mp_zombie_ark`) and Descent (`mp_zombie_h2o`).
It automatically attempts to give **only `iw5_mors_mp`**, once per human
connection after a live spawn; bots are skipped. The native Zombies giver
may replace your equipped primary if your weapon slots are full.

Look for console markers prefixed `[EZWT]`:
`MAIN`, `INIT`, `READY`, `PLAYER`, `GIVE_BEGIN`, `GIVE_RETURNED`, `OWNED`,
and `EQUIPPED`. `SKIP`, `DISABLED`, `TIMEOUT`, `NOT_OWNED` or `NOT_EQUIPPED`
explain where the test stopped or what check failed.
No `MAIN` marker means entrypoint execution was not observed: check the
loader path and compilation logs. A missing `GIVE_RETURNED` means the native
grant did not finish; it does **not** by itself prove missing assets.

This test does not precache or load assets, change the printer, or add upgrade
support. Missing assets can cause script errors or crashes. **Do not upgrade
the test weapon.** Even `EQUIPPED` does not prove it can fire or animate.
Send the full `[EZWT]` output and any script/engine errors, your map name,
and whether the weapon appeared and fired. Remove the test after diagnosis.

## Missing multiplayer weapons in Exo Zombies

Install `scripts/zm/exo_zombies_dlc_weapons_all_maps.gsc` at
`s1/scripts/zm/exo_zombies_dlc_weapons_all_maps.gsc`. One auto-loaded script
supports all four maps; no per-map linker GSC copies are needed:

| Map | Map name | DLC |
| --- | --- | --- |
| Outbreak | `mp_zombie_lab` | 1 |
| Infection | `mp_zombie_brg` | 2 |
| Carrier | `mp_zombie_ark` | 3 |
| Descent | `mp_zombie_h2o` | 4 |

Set `scr_zm_dlc_weapons_enabled 1` (default) before loading a map to enable
the script, or `0` to disable it. Set `scr_zm_dlc_weapons_debug 1` for
per-weapon console logs (default `0`). Unsupported maps are skipped.

After native printer initialization, it adds missing **regular MP and MP
DLC weapon families**, not cross-map wonder weapons, to `level.magicboxweapons`.
The catalog follows this repository's multiplayer Gun Game weapon list,
including AE4, OHM, M1 Irons, Blunderbuss and the additional MP DLC families.
It selects one stats-table-registered representative per family (a base
weapon if registered, otherwise a loot variant), rather than every skin.
Unregistered families are logged and skipped. Registration in the stats
table does **not** prove that a Zombies map has loaded those assets.

Existing printer entries are preserved. A native Zombies version or an
existing MP variant counts as the same weapon family, so it is not added
twice. Added weapons use their world models for the printer display.
If initialization times out, it logs the failure without creating a fake
pool. Other GSC scripts can call
`scripts\zm\exo_zombies_dlc_weapons_all_maps::get_map_weapons(dlc)` for
the MP candidate catalog on a supported map,
`scripts\zm\exo_zombies_dlc_weapons_all_maps::get_mp_roster()`
for the complete MP candidate catalog (`get_dlc_roster()` remains an alias), or
`player scripts\zm\exo_zombies_dlc_weapons_all_maps::give_dlc_weapons_to_player(weaponName)`
to grant one selected, precached weapon.

**Asset prerequisite:** GSC registration and `precacheitem()` do not load
missing fastfile assets. Your mod must supply the registered MP weapons,
their models and compatible camo/attachment combinations used by native
Zombies upgrades. The script retains native Zombies giving and upgrade
state; it does not implement new MP upgrade assets or disable the kiosk.
MP Mk2-Mk25 upgrade support is **not verified** and requires a compatible
mod. Test purchases, reacquisition and upgrades before using this in a
live match; missing assets can cause script errors or map-load failures.

Linker declarations such as `weapon,<asset-name>` belong in your mod's
zone/linker source, **not** in this GSC file. This script now intentionally
uses multiplayer `iw5_*_mp` IDs, **not** the shop's `iw5_*zm_mp` roster.
This repository contains no zone sources, so none are generated here.
