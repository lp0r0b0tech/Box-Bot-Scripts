# Loading the Exo Zombies shop weapons with a ZoneTool fastfile

> **Status: built and verified with ZoneTool's own loader, not yet tried in the game.**
> The pack loads through the game's fastfile loader and contains all 27 shop weapons. Whether the client
> mounts it as intended (`loadmod`, a real zombies map, the shop script) still has to be confirmed on the
> game itself. See [Not verified](#not-verified).

The shop (`scripts/zm/s1_scripts_zm_exo_zombies_dlc_weapon_shop.gsc`) can only sell a weapon the game has
loaded. A GSC script cannot load fastfiles, and a zombies map's default fastfiles hold only a few of the shop's
27 weapons (on `mp_zombie_lab` the runtime log showed 1 of 27 registered). The fix is a fastfile that contains
all of them. This directory builds one with [ZoneTool](https://github.com/Joelrau/x64-zt):
`mods/exo_weapons_all/mod.ff`, which the client loads when `fs_game` is `mods/exo_weapons_all`.

"The shop" here is the advanced version of that file: the one with the `mods/exo_weapons_*` pack logic that
writes `s1/dlcws_runtime_status.log` (added to the repository by PR #14). The shorter version that was on `main`
before has a different roster of `*zm_mp` weapons and none of this logic; the pack is built for the advanced roster.

The `*.zone` files in the repository root are asset listings, not ZoneTool input. They do not need to change.

## Quick start

On the machine where the pack was built:

```bash
zonetool/install-pack.sh        # copies ~/zonetool-workspace/exo_weapons_all.ff to <game>/mods/exo_weapons_all/mod.ff
```

Then start the game, open the console from the **main menu** (not in a match) and run:

```text
loadmod mods/exo_weapons_all
```

The client restarts itself with the mod. Start Exo Zombies and look at the last block of
`s1/dlcws_runtime_status.log` (it is appended to on every map start). A working setup logs
`fs_game=mods/exo_weapons_all` and 27 `weapon=<id> registered` lines (`pack=loaded` alone only means that at least
one roster weapon is registered, which is also true without the pack).
Launching with `-mod mods/exo_weapons_all` is the equivalent. `unloadmod` (or deleting the folder) undoes it.

The `.ff` is 152 MB and consists of the game's own assets, so it is **not committed**. Build it with the
steps below.

## What the pack contains

28 weapons: the 27 in the shop roster, plus `iw5_linegundamagezm_mp`, the weapon the Line Gun script fires for
damage. In total 7,032 assets: 46 attachments, 249 models with their surfaces and 1,551 animations,
1,789 sounds, 171 effects, 675 images, 396 materials, 140 techsets and their shaders, and 58 localized strings.

| Taken from | Weapons (shop name = ID) |
|---|---|
| `common_mp` | Thor `iw5_thor_mp`, Riot Shield `iw5_riotshieldt6_mp`, MAAWS `iw5_maaws_mp`, M990 `iw5_m990_mp`, Stinger M7 `iw5_stingerm7_mp` |
| `patch_common_mp` (wins over `common_mp`) | MP443 `iw5_pbw_mp`, EPM3 `iw5_epm3_mp`, MDL `iw5_microdronelauncher_mp`, MORS `iw5_mors_mp`, XMG (Dual) `iw5_exoxmg_mp`, 1911 `iw5_dlcgun13_mp`, AK-47 `iw5_dlcgun7loot0_mp`, Lever Action `iw5_dlcgun33_mp`, M1 Garand `iw5_dlcgun23_mp`, M16 `iw5_dlcgun7loot6_mp`, MP40 `iw5_dlcgun18_mp`, Repulsor `iw5_dlcgun38_mp`, STG-44 `iw5_dlcgun6_mp`, SVO `iw5_dlcgun6loot5_mp`, Sten `iw5_dlcgun28_mp` |
| `mp_zombie_h2o` | DLC Weapon I `iw5_dlcgun1zm_mp`, Ohm `iw5_dlcgun2zm_mp`, DLC Weapon III `iw5_dlcgun3zm_mp`, Blunderbuss `iw5_dlcgun4zm_mp`, Trident `iw5_tridentzm_mp` |
| `mp_zombie_ark` | Line Gun `iw5_linegunzm_mp` (and `iw5_linegundamagezm_mp`) |
| `mp_zombie_brg` | Microwave `iw5_microwavezm_mp` |

The source of truth is [`zonetool/exo_weapons_all.csv`](zonetool/exo_weapons_all.csv). To drop a weapon from the
pack, delete its `weapon,` line and rebuild.

## Building the pack

Requirements: Linux with Wine (GE-Proton, default `GE-Proton11-11`), `gamescope`, `xdotool`, `ffmpeg`,
`systemd-run`, `python3`, `unzip` and `gh` (or set `ZT_ZIP` to a downloaded `Release.zonetool.zip`), the game
installed, about 10 GB of free disk and 14 GB of RAM. ZoneTool is the `latest` release of `Joelrau/x64-zt`
(tested with `latest-2-g3802db4`). The game folder is only ever read. On Windows, run `zonetool.exe` from the game
folder with the same arguments; the scripts here are Linux/Wine wrappers (Windows is untested).

All commands run from the repository's `zonetool/` directory. `WS` is the workspace everything is written to
(every script honours it; the default is `~/zonetool-workspace`) and `GAME` overrides the game location.

```bash
export WS="$HOME/zonetool-workspace"

# 1. Workspace: downloads ZoneTool, patches it (see "ZoneTool bugs"), symlinks the game's fastfiles
./setup-shadow-workspace.sh

# 2. Dump the base zones whole (one process each)
./run-zonetool.sh -dumpzone patch_common_mp
./run-zonetool.sh -dumpzone common_mp
./run-zonetool.sh -dumpzone techsets_common_core_mp
./run-zonetool.sh -dumpzone code_post_gfx_mp

# 3. Dump the zombie zones (only the asset types a weapon pack needs, one process per zone)
./dump-zones.sh mp_zombie_h2o mp_zombie_ark mp_zombie_brg common_zm_mp common_zombie_mp

# 4. Dump the display names of the Trident and Line Gun (they live in the per-map English zones)
./dump-localize.sh eng_mp_zombie_h2o eng_mp_zombie_ark

# 5. Add the pack source and the copied Magnetron string, then blank the broken camo field in the weapon JSONs
#    (patch-weapons.py resolves the CSV's paths relative to the workspace, so it runs from there)
cp -r exo_patch "$WS/dump/"
cp exo_weapons_all.csv "$WS/zone_source/"
(cd "$WS" && python3 "$OLDPWD/patch-weapons.py" zone_source/exo_weapons_all.csv dump/exo_patch)

# 6. Build and load-test it (about 8 minutes)
./build-verify.sh exo_weapons_all
```

Step 6 ends with a verdict line such as
`exo_weapons_all: built 152400596 bytes; verify OK after 7032 assets; last=rawfile exo_weapons_all`. The result is
`$WS/exo_weapons_all.ff`; install it with `./install-pack.sh`. A run that crashed or hit an engine "Fatal Error"
dialog says so in its verdict line and leaves a screenshot in `$WS/logs/fatal-*.png`.

## Technical notes

**Search order.** `addpath` lines in the CSV are searched top to bottom and the first directory holding an asset
wins. `exo_patch` is first (patched weapon JSONs, the copied Magnetron string), then the zombie map zones, then
`patch_common_mp`, then `common_mp`. `techsets_common_core_mp` and `code_post_gfx_mp` are needed as paths because
the shader and techset files `common_mp` references live in them. Without them the build dies on a missing shader.

**ZoneTool bugs, and the workarounds.**
- The FX writer emits a third decal material that does not exist and crashes `-buildzone`.
  `patch-zonetool.py` changes one byte of `zonetool.exe` (idempotent, keeps `zonetool.exe.orig`).
- The weapon writer copies `camoViewModelMaterialOverride` as a raw pointer, which crashes the game while loading
  the weapon. `patch-weapons.py` writes patched JSON copies with the field blanked (stock weapons do the same).
  The viewmodel camo override of the pack's weapons is therefore empty.

**Localized strings.** Every weapon's display name is built into the zone, and a missing string is fatal. The build
only sees strings of zones it has loaded. `ZOMBIE_WEAPON_TRIDENT_NAME` and `ZOMBIE_WEAPON_LINEGUN_NAME` only exist
in per-map English zones, hence step 4. `ZOMBIES_WEAPON_MWG` (the Microwave Gun, which the game calls "Magnetron")
lives in `eng_patch_code_post_gfx_zm_mp`, so `exo_patch/localizedstrings/ZOMBIES_WEAPON_MWG` is a copy of that
string; the pack would otherwise override the game's text with a different one. Every localized string in the pack
equals its retail value (all 137 English zones were searched), except `WEAPON_ATTACHMENT_MAHEM_SCOPE`, which is an
empty string where retail has a single space.

**Engine limits while dumping.** The engine's image and material pools (13,792 and 11,648) cannot be enlarged, so
each big zone is dumped in its own process. `-buildzone` has no such limit. The finished pack is small against
those pools: of its 675 images and 396 materials only 54 and 39 are not already in the always-loaded common
zones (`common_mp`, `patch_common_mp`, `code_post_gfx_mp`, `common_zm_mp`, `common_zombie_mp`).
English-zone dumps pile up fonts (limit 64), so `dump-localize.sh` is meant for at most about 10 zones per
process, and `unloadzones` must not be used between them.

**Running ZoneTool headless under Wine.** `run-zonetool.sh` uses DXVK's `d3d11`/`dxgi`, a private headless
`gamescope` for Wine's display, a copied `fileSysCheck.cfg`, and a memory cap through `systemd-run`.
`zone/` must not exist in the workspace (builds land in the workspace root). `console-run.sh` feeds a command file
to ZoneTool's console (lines end in CR) and reports `dumped=`, `fatal=` and `crash=` in one verdict line;
the wrapper's own exit status is always 0. A dump is complete when the log has `Zone "<name>" dumped.` and the
CSV's size is not a multiple of 4096. `-verifyzone` doubles as a cheap asset lister (`Loading asset "x" of type y.`).

## Not verified

- **In-game mounting.** Nothing here was run in the game. The mod path (`<game>/<fs_game>/mod.ff` loaded after the
  common zones, `loadmod`, `-mod`) is taken from the h1-mod client source, which the S1x and s1-mod clients share;
  `s1x.exe` and `s1-mod.exe` contain the matching `mod.ff`, `loadmod`, `unloadmod` and `-mod %s` strings.
  It also assumes the client still loads the shop script from `s1/scripts/` while `fs_game` is set. The log's
  `fs_game=` and `pack=` fields show whether the shop ran against the pack.
- **Duplicate definitions.** The Trident, Line Gun, Microwave and DLC ZM weapons are also defined by their own map
  zones, so on those maps the weapon is defined twice (later load wins, as with the patch zones). Expected to be
  harmless, not tested.
- **Cosmetic gaps.** Six trail materials (`smoke_trail_dear`, `_m990`, `_mors`, `_ohm_machinegun`, `_sniper`,
  `trail_epm3_plasma`) exist in no retail zone and fall back to the default material. The camo override above is empty.
- **Pool headroom** on a very large map is estimated (see above), not measured.
