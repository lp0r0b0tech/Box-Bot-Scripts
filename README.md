put scripts folder into s1 folder
put bots.txt in s1 folder 2

## Shared Exo Zombies DLC weapons

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

After native printer initialization, it adds missing DLC/energy weapons
from the shop's roster to `level.magicboxweapons`, preserving existing
entries. Added weapons use their world models for the printer display.
If initialization times out, it logs the failure without creating a fake
pool. Other GSC scripts can call
`scripts\zm\exo_zombies_dlc_weapons_all_maps::get_map_weapons(dlc)` for
the per-map missing table, `scripts\zm\exo_zombies_dlc_weapons_all_maps::get_dlc_roster()`
for the complete target roster, or
`player scripts\zm\exo_zombies_dlc_weapons_all_maps::give_dlc_weapons_to_player(weaponName)`
to grant one selected, precached weapon.

**Asset prerequisite:** GSC registration and `precacheitem()` do not load
missing fastfile assets. Your mod must supply every listed weapon, model,
upgrade variant, and the cross-map wonder-weapon behavior/FX callbacks.
In particular, `iw5_blunderbusszm_mp` is a shop/mod ID; the native DLC4
Blunderbuss uses `iw5_dlcgun4zm_mp`, and Exo Minigun is normally a Goliath
killstreak weapon. These require compatible mod assets/handling.

Linker declarations such as `weapon,<asset-name>` belong in your mod's
zone/linker source, **not** in this GSC file. Use the exact `iw5_*zm_mp`
IDs returned by `get_dlc_roster()` rather than substituting MP IDs or
unverified names such as `iw5_cellfusion_zm`/`iw5_limbo_zm`.
This repository contains no zone sources, so none are generated here.
