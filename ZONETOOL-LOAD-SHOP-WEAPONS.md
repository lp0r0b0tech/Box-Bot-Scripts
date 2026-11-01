# Loading the Exo Zombies shop weapons with ZoneTool

This explains how the Exo Zombies DLC weapon shop gets its MP/DLC guns to
actually load in-game, using **ZoneTool** to rebuild the map **patch**
fastfiles. It documents the change in this repo and the build/install loop you
run on your own machine (ZoneTool needs the game present, so it can't be run or
tested from CI or a sandbox).

## Why this is needed

A GSC script **cannot** mount or load a fastfile at runtime. The engine fixes
which weapon assets a map has when the map's fastfiles load. So the shop can
only ever hand out a weapon whose definition is already loaded
(`getweaponbasename(name) == name`). The shop code (see
`scripts/zm/s1_scripts_zm_exo_zombies_dlc_weapon_shop.gsc`) already sells **any**
roster weapon that is registered and refunds anything that isn't — so the real
job is to get the weapon definitions loaded. That is what ZoneTool does here.

## How the weapons are added: patch fastfiles

Each Exo Zombies map loads a small **patch** fastfile on top of the stock map:

| Map  | Patch zone source            |
|------|------------------------------|
| h2o  | `patch_mp_zombie_h2o.zone`   |
| lab  | `patch_mp_zombie_lab.zone`   |
| brg  | `patch_mp_zombie_brg.zone`   |
| ark  | `patch_mp_zombie_ark.zone`   |

These patch fastfiles already bring one extra weapon into zombies — the EM1 —
via this block (h2o shown):

```
phys_collmap,,weapon_em1
physpreset,,weapon_heavy
laser,,em1_laser
weapon,iw5_em1zm_mp
```

That EM1 block is the template. To load the rest of the shop roster, this repo
adds the shop's missing MP/DLC guns as `weapon,` lines right after the EM1 line
in all four patch zones (20 weapons per map):

```
weapon,iw5_thor_mp            # Thor
weapon,iw5_dlcgun13_mp        # 1911
weapon,iw5_pbw_mp             # MP443
weapon,iw5_dlcgun7loot0_mp    # AK-47
weapon,iw5_epm3_mp            # EPM3
weapon,iw5_riotshieldt6_mp    # Riot Shield
weapon,iw5_dlcgun33_mp        # Lever Action
weapon,iw5_dlcgun23_mp        # M1 Garand
weapon,iw5_dlcgun7loot6_mp    # M16
weapon,iw5_maaws_mp           # MAAWS
weapon,iw5_microdronelauncher_mp  # MDL
weapon,iw5_m990_mp            # M990
weapon,iw5_dlcgun18_mp        # MP40
weapon,iw5_dlcgun38_mp        # Repulsor
weapon,iw5_dlcgun6_mp         # STG-44
weapon,iw5_dlcgun6loot5_mp    # SVO
weapon,iw5_stingerm7_mp       # Stinger M7
weapon,iw5_dlcgun28_mp        # Sten
weapon,iw5_mors_mp            # MORS
weapon,iw5_exoxmg_mp          # XMG (Dual)
```

> The `# ...` labels above are just for this doc — do **not** put them in the
> `.zone` files. The committed zone files contain only the bare `weapon,<name>`
> lines.

The shop's zombies **wonder weapons** (`iw5_microwavezm_mp`,
`iw5_linegunzm_mp`, `iw5_tridentzm_mp`) are *not* added here because most maps
already load them in the base fastfile (adding a duplicate makes the build
fail). If a specific map's shop reports one of those as "not loaded", add just
that `weapon,` line to that map's patch — check the map's base `.zone`
(`mp_zombie_h2o.zone`, `mp_zombie_lab.zone`) first to avoid a duplicate.

## Build loop (run on your machine with the game installed)

ZoneTool for Advanced Warfare is the x64 fork: https://github.com/Joelrau/x64-zt
(AW is game id **s1**). Follow its README for exact setup; the flow is:

1. Put the patch `.zone` sources from this repo in ZoneTool's `zone_source/`.
2. Make the weapons' assets available to the linker before building — load the
   fastfile(s) that already contain each gun (e.g. the MP common/DLC zones),
   then build the patch, e.g.:
   ```
   buildzone patch_mp_zombie_h2o
   buildzone patch_mp_zombie_lab
   buildzone patch_mp_zombie_brg
   buildzone patch_mp_zombie_ark
   ```
3. **Resolve per-weapon dependencies iteratively.** Like the EM1 block, some
   guns also need their own `phys_collmap`, `physpreset`, `laser`, scope/reticle
   `material`/`image`, or `attachment` assets. The build will error naming any
   missing asset — add that line to the patch zone and rebuild until it links
   cleanly. Use `dumpzone` on a fastfile that already has the gun to discover its
   exact dependency names.

## Install

1. **Back up** your existing `zone/<lang>/patch_mp_zombie_*.ff` first.
2. Copy the rebuilt `patch_mp_zombie_{h2o,lab,brg,ark}.ff` into the game's zone
   folder (where the stock patch fastfiles live).
3. Launch AW through S1x and load each Exo Zombies map.

(Do not edit files inside the read-only game install from here — build the
`.ff` in your ZoneTool workspace, then copy them in manually.)

## Verifying + tuning the roster

- Open the shop in-game. Weapons whose definitions loaded appear buyable;
  anything still unresolved shows as "not loaded" and is refunded if bought
  (crash-safe) — so a partial build is still safe to ship.
- Campaign-only guns can need extra ported assets; if one refuses to build,
  leave it out and the shop simply won't offer it on that map.
- Note the roster and the patch weapon lists must stay in sync: the shop roster
  lives in `dlcws_build_weapon_list()` in the shop GSC.

## Related

- Shop behavior / default-fastfile fallback: PR that reworks
  `exo_zombies_dlc_weapon_shop.gsc` to sell whatever is registered.
- This change is additive (zone sources only) and does not alter the shop GSC.
