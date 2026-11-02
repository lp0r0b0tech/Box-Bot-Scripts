# Loading the Exo Zombies shop weapons with a ZoneTool fastfile

> **Status: the pack loads and all 27 shop weapons register in the game (test 5), but that build had three visible
> defects. The current build targets them and has not been tried in the game yet.**
> In the game, `+set fs_game mods/exo_weapons_all` did **not** mount the pack, while `+loadmod mods/exo_weapons_all`
> did (`s1x.exe` had `mod.ff` open). Zombies then stopped loading a map with `Exceeded limit of N '<type>' assets`
> until the animation pool (`xanim`, N = 5800) was relieved (see **Asset pool limits while playing**). Test 5 then
> loaded `mp_zombie_lab` with all 27 weapons registered, but the multiplayer weapons were red floating boxes (they
> still fired), the wonder weapons had no reload sound, and the Line Gun had no visible projectile and did no damage.
> The current build packs the multiplayer weapons' real models (**Transient zones**), the assets the Line Gun's script
> needs (**Line Gun support**) and PCM instead of FLAC sounds (**FLAC sounds**). The pack also holds two helper
> weapons for the Line Gun. See [Not verified](#not-verified).

The shop (`scripts/zm/s1_scripts_zm_exo_zombies_dlc_weapon_shop.gsc`) can only sell a weapon the game has
loaded. A GSC script cannot load fastfiles, and a zombies map's default fastfiles hold only a few of the shop's
27 weapons (on `mp_zombie_lab` the runtime log showed 1 of 27 registered). The fix is a fastfile that contains
all of them. This directory builds one with [ZoneTool](https://github.com/Joelrau/x64-zt):
`mods/exo_weapons_all/mod.ff`, which the client loads when graphics assets load (start-up or `vid_restart`) while
`fs_game` is `mods/exo_weapons_all`.

"The shop" here is the advanced version of that file: the one with the `mods/exo_weapons_*` pack logic that
writes `s1/dlcws_runtime_status.log` (added to the repository by PR #14). The shorter version that was on `main`
before has a different roster of `*zm_mp` weapons and none of this logic; the pack is built for the advanced roster.

The `*.zone` files in the repository root are asset listings, not ZoneTool input. They do not need to change.

## Quick start

On the machine where the pack was built:

```bash
zonetool/install-pack.sh        # copies ~/zonetool-workspace/exo_weapons_all.ff to <game>/mods/exo_weapons_all/mod.ff
```

Installing the file is not enough: the client only mounts the pack while `fs_game` is `mods/exo_weapons_all` **and
the renderer (re)starts**. Until then the advanced shop says `Weapon shop pack not loaded`. The `loadmod` command
does both: it sets `fs_game`, then runs `vid_restart`.

**CB Servers launcher (S1x).** Open the game's page, click the cog wheel (Game Settings), open **Advanced**, and
type this into **Launch Options**:

```text
+loadmod mods/exo_weapons_all
```

Then start Zombies from the launcher. The launcher puts that text on the `s1x.exe` command line
(`s1x.exe -noupdate -zombies <Launch Options> +set name <player>`); it passes no `fs_game` by default. The field is
saved per game as `aw-launch-options` in `%LOCALAPPDATA%\cbservers\user\properties.json` (on Linux, the same path
inside the launcher's Proton prefix). Close the launcher before editing that file by hand. Clear the field to undo.

Do **not** use `+set fs_game mods/exo_weapons_all` on its own: it sets the dvar only after the start-up graphics
load, so nothing mounts the pack (the first test did exactly this). Do not combine `+set fs_game X` with
`+loadmod X` either: `loadmod` does nothing when `fs_game` already equals its argument.

**Any other way of starting `s1x.exe`.** Add `+loadmod mods/exo_weapons_all` to its command line (for a Steam
shortcut, its Launch Options).

**From the console** (main menu, not in a match; Multiplayer, Zombies and Survival only, not the campaign): run
`loadmod mods/exo_weapons_all` (or just `vid_restart` when `fs_game` is already `mods/exo_weapons_all`), then start
the match. It does not restart the process. `unloadmod` clears `fs_game` and restarts the renderer again.

To check it, start Exo Zombies and look at the last block of `s1/dlcws_runtime_status.log` (it is appended to on
every map start). A working setup logs `fs_game=mods/exo_weapons_all` and 27 `weapon=<id> registered` lines
(`pack=loaded` alone only means that at least one roster weapon is registered, which is also true without the pack).
To remove the pack, undo the launch option or delete `mods/exo_weapons_all`.

If a map stops loading with `Exceeded limit of N '<type>' assets`, an engine pool is full (N = 5800 is the animation
pool, `xanim`). The message only appears in the error box, so note the type and N, and see
**Asset pool limits while playing** in the technical notes.
`zonetool/watch-s1x-fds.sh` (Linux) logs the fastfiles `s1x.exe` opens, in order, which shows what was loaded when
it stopped.

The `.ff` is about 190 MB (150 MB in test 5, before the real models, the Line Gun's assets and the PCM sounds were
added) and consists of the game's own assets, so it is **not committed**. Build it with the steps below.

## What the pack contains

29 weapons: the 27 in the shop roster, plus two helpers for the Line Gun: `iw5_linegundamagezm_mp`, the weapon its
script fires for damage, and `iw5_dlcwscamo41_mp`, a marker weapon that script wants registered (see **Line Gun
support**). In total 6,979 assets: 46 attachments, 250 models with their 464 surfaces and 842 animations, 1,841 sounds
(923 sound aliases and 918 loaded sounds, 917 of them PCM and one empty), 175 effects, 817 images, 462 materials,
160 techsets and their shaders, 58 localized strings and one tracer (every weapon's tracer is set to `defaulttracer`
and its attachment animation overrides are empty, see **Asset pool limits while playing**).

| Taken from | Weapons (shop name = ID) |
|---|---|
| `common_mp` | Thor `iw5_thor_mp`, Riot Shield `iw5_riotshieldt6_mp`, MAAWS `iw5_maaws_mp`, M990 `iw5_m990_mp`, Stinger M7 `iw5_stingerm7_mp` |
| `patch_common_mp` (wins over `common_mp`) | MP443 `iw5_pbw_mp`, EPM3 `iw5_epm3_mp`, MDL `iw5_microdronelauncher_mp`, MORS `iw5_mors_mp`, XMG (Dual) `iw5_exoxmg_mp`, 1911 `iw5_dlcgun13_mp`, AK-47 `iw5_dlcgun7loot0_mp`, Lever Action `iw5_dlcgun33_mp`, M1 Garand `iw5_dlcgun23_mp`, M16 `iw5_dlcgun7loot6_mp`, MP40 `iw5_dlcgun18_mp`, Repulsor `iw5_dlcgun38_mp`, STG-44 `iw5_dlcgun6_mp`, SVO `iw5_dlcgun6loot5_mp`, Sten `iw5_dlcgun28_mp` |
| `mp_zombie_h2o` | DLC Weapon I `iw5_dlcgun1zm_mp`, Ohm `iw5_dlcgun2zm_mp`, DLC Weapon III `iw5_dlcgun3zm_mp`, Blunderbuss `iw5_dlcgun4zm_mp`, Trident `iw5_tridentzm_mp` |
| `mp_zombie_ark` | Line Gun `iw5_linegunzm_mp` (and `iw5_linegundamagezm_mp`) |
| `mp_zombie_brg` | Microwave `iw5_microwavezm_mp` |
| none (written by `patch-weapons.py`) | Marker `iw5_dlcwscamo41_mp`, a copy of `iw5_linegundamagezm_mp` |

The models of the 20 multiplayer weapons (the `common_mp` and `patch_common_mp` rows) are mostly not in those zones:
they come from the stock transient zones `mp_vm_<weapon>_tr` and `mp_wm_<weapon>_tr`, dumped into `weapon_models` (see
**Transient zones**).

The source of truth is [`zonetool/exo_weapons_all.csv`](zonetool/exo_weapons_all.csv). To drop a weapon from the
pack, delete its `weapon,` line and rebuild.

## Building the pack

Requirements: Linux with Wine (GE-Proton, default `GE-Proton11-11`), `gamescope`, `xdotool`, `ffmpeg`, `flac`,
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

# 5. Dump the stock transient zones that define the multiplayer weapons' viewmodels and worldmodels (52 zones, about
#    4 per process; ZoneTool merges all of them into dump/weapon_models). See "Transient zones".
./dump-tr-zones.sh \
  $(for w in ak47 dragunov fm4 leveraction m16 m1911 m1garand mp40 sten stg44; do echo mp_vm_${w}_tr mp_wm_${w}_tr; done) \
  $(for w in epm3 exoxmg m990 maaws mors pbw stingerm7 thor; do echo mp_{vm,wm}_${w}{,_2}_tr; done)

# 6. Add the pack source and the copied Magnetron string, then patch the weapon JSONs: blank the broken camo field,
#    point every tracer at defaulttracer, empty the animOverrides lists and write the Line Gun's marker weapon
#    (patch-weapons.py resolves the CSV's paths relative to the workspace, so it runs from there)
cp -r exo_patch "$WS/dump/"
cp exo_weapons_all.csv "$WS/zone_source/"
(cd "$WS" && python3 "$OLDPWD/patch-weapons.py" zone_source/exo_weapons_all.csv dump/exo_patch)

# 7. Check that every model, surface, material, techset and image the weapons use was dumped; a hole here is a red
#    box or a crash in the game, and the build does not warn about it. Exit status 1 if anything is missing.
(cd "$WS" && python3 "$OLDPWD/model-closure.py")

# 8. Build and load-test it (8 to 10 minutes)
./build-verify.sh exo_weapons_all

# 9. Decode the FLAC loaded sounds the build used into PCM WAVs (they land in dump/exo_patch/loaded_sound and win the
#    next build) and rebuild. A rebuild can pull in more FLACs: repeat until flac-to-wav.py reports 0 converted. See
#    "FLAC sounds".
(cd "$WS" && python3 "$OLDPWD/flac-to-wav.py" zone_source/exo_weapons_all.csv dump/exo_patch)
./build-verify.sh exo_weapons_all
```

Step 8 and the last build of step 9 end with a verdict line such as
`exo_weapons_all: built 189722898 bytes; verify OK after 6979 assets; last=rawfile exo_weapons_all`. The result is
`$WS/exo_weapons_all.ff`; install it with `./install-pack.sh`. A run that crashed or hit an engine "Fatal Error"
dialog says so in its verdict line and leaves a screenshot in `$WS/logs/fatal-*.png`.

## Technical notes

**Search order.** `addpath` lines in the CSV are searched top to bottom and the first directory holding an asset
wins. `exo_patch` is first (patched weapon JSONs, the copied Magnetron string, the PCM sounds), then the zombie map
zones, then `patch_common_mp`, then `common_mp`. `techsets_common_core_mp` and `code_post_gfx_mp` are needed as paths
because the shader and techset files `common_mp` references live in them. Without them the build dies on a missing
shader. `weapon_models` is last and holds the multiplayer weapons' models (see **Transient zones**).

**ZoneTool bugs, and the workarounds.**
- The FX writer emits a third decal material that does not exist and crashes `-buildzone`.
  `patch-zonetool.py` changes one byte of `zonetool.exe` (idempotent, keeps `zonetool.exe.orig`).
- The weapon writer copies `camoViewModelMaterialOverride` as a raw pointer, which crashes the game while loading
  the weapon. `patch-weapons.py` writes patched JSON copies with the field blanked (stock weapons do the same).
  The viewmodel camo override of the pack's weapons is therefore empty.
- When no dump holds a model's surfaces (`xsurface::init` finds no `.xsb`), ZoneTool copies whatever the running
  engine holds under that name and prints no warning. A clean build and a passing `-verifyzone` therefore prove
  nothing about the models: use `model-closure.py` before the build and dump the finished pack (see **Checking a
  built pack**).

**Transient zones (red boxes).** The main zones `common_mp` and `patch_common_mp` only reference most multiplayer
weapons' `vm_*` and `npc_*` models. The geometry (xmodel and xmodelsurfs) is defined in stock transient zones,
`mp_vm_<weapon>_tr` and `mp_wm_<weapon>_tr` (plus `_2` variants for the larger weapons), which a dump of the main
zones never loads. In test 5 the pack was built without them: ZoneTool silently substituted placeholders (see above),
so the build was clean and verified, yet every multiplayer weapon showed as a red box in the game while still firing.
`dump-tr-zones.sh` dumps those zones (52 are needed, step 5 of the build); ZoneTool writes all `mp_vm_*` and `mp_wm_*`
dumps into one directory, `dump/weapon_models`, and every other `*_tr` zone into `dump/transient_assets`. The recipe
names `dump\weapon_models` as its last `addpath`. `model-closure.py` follows each weapon's model fields through the
models, surfaces, materials, techsets and images and lists what no dump holds: after this change it finds nothing
missing for any of the 29 weapons, and the pack's model surfaces went from 271 to 464.

**Localized strings.** Every weapon's display name is built into the zone, and a missing string is fatal. The build
only sees strings of zones it has loaded. `ZOMBIE_WEAPON_TRIDENT_NAME` and `ZOMBIE_WEAPON_LINEGUN_NAME` only exist
in per-map English zones, hence step 4. `ZOMBIES_WEAPON_MWG` (the Microwave Gun, which the game calls "Magnetron")
lives in `eng_patch_code_post_gfx_zm_mp`, so `exo_patch/localizedstrings/ZOMBIES_WEAPON_MWG` is a copy of that
string; the pack would otherwise override the game's text with a different one. Every localized string in the pack
equals its retail value (all 137 English zones were searched), except `WEAPON_ATTACHMENT_MAHEM_SCOPE`, which is an
empty string where retail has a single space.

**Line Gun support.** The Line Gun does its damage in script, not in the weapon. Only `mp_zombie_ark` (Carrier) ships
that script; on the other maps `exo_zombies_linegun_support.gsc` (deployed in `<game>/s1/scripts/zm/`, not part of this
repository) ports it: each shot sends a line forward and damages every zombie it sweeps through, with a beam effect
and sounds of its own. It does nothing on Carrier, and it stays off (the log says `LineGunSupport: ... support stays
off`) unless `iw5_linegunzm_mp`, `iw5_linegundamagezm_mp` **and** `iw5_dlcwscamo41_mp` are all registered. When it is
on it loads three effects (`vfx/muzzleflash/dlc_zombies_linegun_laser`, `vfx/blood/dlc_zombie_line_gun_gib`,
`vfx/muzzleflash/dlc_zombies_drone_death`) and plays two sounds (`wpn_linegun_beam_hi`, `wpn_linegun_exp`). The test 5
pack had the two weapons but not the marker, the effects or the sounds, so the gun fired plain bullets: no visible
projectile and no damage. No stock zone defines the marker and the scripts only check that the name is registered, so
`patch-weapons.py` writes it as a copy of `iw5_linegundamagezm_mp`, and the recipe names the three effects and the two
sounds. The shop's native-camo check also reads the marker, but it additionally needs two camo-table strings that the
stock table lacks, so the shop keeps its legacy camo handling.

**FLAC sounds (a hypothesis).** ZoneTool embeds a loaded sound as FLAC when only `<name>.flac` exists in the search
paths and as PCM when a `<name>.wav` exists (`loaded_sound::parse` looks for the `.wav` first, in every search path). In
test 5 the wonder weapons (Line Gun, Microwave, Trident) had no reload sound. Every weapon-specific reload notetrack
alias of the Line Gun (8) and the Microwave (4) is FLAC, and so are 7 of the Trident's, while the multiplayer weapons'
reload aliases are PCM. A round-trip dump of the test 5 pack showed that data intact, and the wonder weapons' fire
sounds are FLAC too without anyone reporting them missing, so the cause is not proven. As an experiment
`flac-to-wav.py` decodes every FLAC loaded sound the pack uses into a WAV in `exo_patch/loaded_sound` (bit-exact:
`flac -d` checks the stream's MD5), so the pack now holds PCM only: 918 loaded sounds, 917 of them PCM and one empty.
If the reload sounds are still silent in the game, the cause is elsewhere (the aliases' settings, the loaded-sound
memory budget or the notetrack that plays them); none of that has been tested. The pack's growth from 150 MB to 190 MB
comes from the real models and the effects as well as from the PCM.

**Engine limits while dumping.** The engine's image and material pools (13,792 and 11,648) cannot be enlarged, so
each big zone is dumped in its own process. `-buildzone` has no such limit. English-zone dumps pile up fonts
(limit 64), so `dump-localize.sh` is meant for at most about 10 zones per process, and `unloadzones` must not be
used between them.

**Asset pool limits while playing.** The engine keeps one fixed-size pool per asset type and stops with
`Exceeded limit of N '<type>' assets` when one is full; a script or a pack cannot change the sizes. Test 4
stopped with N = 5800, the size of the animation pool (`xanim`): the zones of a Zombies map already hold roughly
4,400 to 4,850 animations (estimated, see below) and the first two builds added about 1,500 more. `-verifyzone` does
not catch this, because ZoneTool enlarges several pools inside its own process (`init_zonetool()`: xanim, sound,
loaded_sound, weapon, attachment, localize, luafile, leaderboarddef and reverbpreset by 2, computeshader and
equipsndtable by 4, vertexdecl by 6, impactfx by 10), so a pack that verifies there can still be too big for the game.
The sizes in `zonetool/pool-estimate.py` are the pool table of a running ZoneTool with those factors divided out (the
game's own table is stored encoded in `s1_mp64_ship.exe`); only the xanim size has been confirmed by the game's own
error message.

**Anim overrides.** 709 of the first builds' 1,551 animations were referenced by the weapons only through
`animOverrides`, the replacement first-person animations a weapon plays when a given attachment is fitted.
`patch-weapons.py` empties that list in every weapon (`numAnimOverrides` becomes 0, which ZoneTool writes as no list,
like a stock weapon without overrides). The pack then holds 842 animations, 792 of them not already loaded by the base
zones, and a weapon with an attachment plays its base animations instead. If a pool is still full, the next options
are to blank the left/right-hand animation sets of every weapon except `iw5_exoxmg_mp` (the only shop weapon with an
akimbo variant; 122 fewer animations) and to build a pack per map without the weapons that map defines itself.

**Tracers.** The first suspect for the first `Exceeded limit` error (its pool name was not captured) was the tracer
pool (32 slots): the weapons named 15 different tracers, 14 of them not in the base zones, and the estimate was 31 to
34 of 32. `patch-weapons.py` therefore points every tracer of the pack's weapons and attachments at `defaulttracer`,
which `code_post_gfx_mp` already defines; only the look of the bullet tracers changes. The overflow that was then seen
was the xanim pool, so this is a precaution. The pack holds one tracer and the estimate is 17 to 20 of 32.

**Estimate.** `zonetool/pool-estimate.py` applies this model (read from the game binary, not observed): every asset a
zone defines takes a slot, except one whose name is already loaded from a zone with the same load flags. It reads the
zones' asset lists and the pack's `-verifyzone` log, for `mp_zombie_lab`, `_ark`, `_brg` and `_h2o`. The zones are the
ones `watch-s1x-fds.sh` logged while a Zombies map loaded: `code_pre_gfx_mp`, `code_post_gfx_mp`,
`code_post_gfx_zm_mp`, `common_zm_mp`, `common_bots_mp`, `common_core_zm_mp` and the map's own zones, each with its
`patch_` and English (`eng_`, `eng_patch_`) variants (`ui_mp` and `ui_zm_mp` are unloaded when the map starts). The mod
zone loads right after `common_zm_mp`, so a pack asset that the first four zones define costs nothing. `csv-zones.sh`
writes the lists; the zones it did not dump (`code_pre_gfx_mp`, `common_bots_mp` and the maps' `_load` and `_path`
zones) are small and skipped, so the real use is a little higher. For the current build, without the pack and with it
(the share of the pool, with the pack):

| Map | xanim (5,800) | loaded_sound (7,000) | localize (13,600) |
|---|---|---|---|
| `mp_zombie_lab` | 4,435 to 5,227 (90%) | 5,554 to 5,743 (82%) | 13,364 to 13,366 (98%) |
| `mp_zombie_ark` | 4,846 to 5,638 (97%) | 6,065 to 6,254 (89%) | 13,433 to 13,435 (99%) |
| `mp_zombie_brg` | 4,766 to 5,558 (96%) | 5,990 to 6,179 (88%) | 13,410 to 13,412 (99%) |
| `mp_zombie_h2o` | 4,839 to 5,631 (97%) | 6,836 to 7,025 (**100.4%, 25 over**) | 13,421 to 13,423 (99%) |

Every other pool stays under 90% (`equipsndtable` is 1 of 1 without the pack, and the pack adds none). The same model
puts the test 3 and 4 builds at 102% (`mp_zombie_lab`) to 109% (`_ark`, `_h2o`) of the xanim pool, which is what the
game reported. loaded_sound is the tightest: `mp_zombie_h2o` needs 7,025 of 7,000 if a pack asset that the first four
zones define costs nothing, as modelled, and up to 7,754 (111%) if the engine kept both copies. The pack's copies of
the sounds of the weapons that map defines itself (`dlcgun1zm` to `4zm`, `tridentzm`) are charged in both figures: 151
of the pack's 918 loaded sounds are also defined by `mp_zombie_h2o`. A pack for that map without those five weapons
(delete their `weapon,` lines) would therefore free up to 151 slots by the model. Only the xanim limit has been
confirmed in the game, so the loaded_sound figures are a prediction; only `mp_zombie_lab` has been played.

**Checking a built pack.** `-verifyzone` only shows that the zone loads inside ZoneTool, so dump the finished pack and
look at what it holds. Copy it to another name first (`dumpzone` needs a `dump/<zone>` that does not exist yet), write
a command file of `loadzone common_mp`, `loadzone techsets_common_core_mp`,
`dumpzone s1 <copy> weapon,attachment,xanim,sound,loaded_sound,fx,xmodel,xmodelsurfs` and `quit`, and run
`console-run.sh <tag> <command file>`; it takes about 20 seconds (`assets=0` in the verdict is normal for a dump, look
at `dumped=1`). Dumping a zone that the same process has already loaded never finishes. For the current pack the
counts of that dump equal the build log's (29 weapons, 46 attachments, 250 xmodels, 464 xsurfaces, 842 xanims, 175 fx,
923 sound aliases, 918 loaded sounds of which 917 are `.wav`); it holds the marker weapon, the Line Gun's effects and
`wpn_linegun_*` aliases, and the 194 decoded WAVs byte for byte. A byte comparison of its `.xsb` surface files with the
stock dumps shows differences that are not defects: ZoneTool's dumper writes an array that lies inside an earlier one as
a 9-byte reference record instead of the data, a stock surface shares its triangle indices that way, and the pack stores
each array separately, so the pack's file is `6 * triangles - 3` bytes larger per such surface (for example 1,858
triangles, +11,145 bytes). With the references resolved and pointer fields ignored, all 464 surfaces match the stock
dump they were taken from (checked with a throwaway script that is not part of this directory).

**Running ZoneTool headless under Wine.** `run-zonetool.sh` uses DXVK's `d3d11`/`dxgi`, a private headless
`gamescope` for Wine's display, a copied `fileSysCheck.cfg`, and a memory cap through `systemd-run`.
`zone/` must not exist in the workspace (builds land in the workspace root). `console-run.sh` feeds a command file
to ZoneTool's console (lines end in CR) and reports `dumped=`, `fatal=` and `crash=` in one verdict line;
the wrapper's own exit status is always 0. A dump is complete when the log has `Zone "<name>" dumped.` and the
CSV's size is not a multiple of 4096. `-verifyzone` doubles as a cheap asset lister (`Loading asset "x" of type y.`).

## Not verified

- **In-game behaviour.** Five tests so far, all through the CB Servers launcher. Test 1 started without `fs_game`
  (the launcher passes none unless Launch Options sets it): the shop correctly logged `fs_game=` and
  `pack=not_loaded` with one weapon registered. Test 2 used `+set fs_game mods/exo_weapons_all`: the log showed
  `fs_game=mods/exo_weapons_all` but still `pack=not_loaded` on `mp_zombie_lab` with one weapon registered, so the
  zone was not mounted (and the shop script does load while `fs_game` is set). The CBServers/s1-mod client source
  (`src/client/component/mods.cpp`) and the game binary explain it, though neither was run for this:
  `<game>/<fs_game>/mod.ff` is added as a zone only when graphics assets load, which happens during start-up before
  the `+` command-line commands run, so a `+set` is too late. `loadmod` sets `fs_game` and then runs `vid_restart`,
  which loads the graphics assets again with the pack. Test 3 used `+loadmod mods/exo_weapons_all`: `s1x.exe` had
  `mod.ff` open, so the pack mounted (and the extra `vid_restart` did no harm), and the game then stopped loading a
  Zombies map with `Exceeded limit of N '<type>' assets`. The type and N were not captured. Test 4 used the build with
  every tracer set to `defaulttracer` and stopped the same way, with N = 5800: the `xanim` pool (see above). The shop
  never ran in tests 3 and 4, so the log was not updated. Test 5 used the build with empty `animOverrides`:
  `mp_zombie_lab` loaded and all 27 weapons registered. In it the multiplayer weapons were red floating boxes that
  still fired, the wonder weapons had no reload sound, and the Line Gun had no visible projectile and did no damage.
  The log's `fs_game=` and `pack=` fields show whether the shop ran against the pack.
- **The fixes for the test 5 defects have not been tried (test 6 is pending).** What this guide says about them comes
  from the pack's contents and the scripts, not from the game. The real models are packed and every surface matches
  its stock dump, but how the weapons render is not known. The Line Gun script now finds all three weapons, the
  effects and the sounds it needs, but whether it deals damage and shows the beam is not known (after a retest, look
  for the console line `LineGunSupport: ready.`; `support stays off` means it still lacks a weapon). The PCM sounds are
  an experiment: whether they bring the wonder weapons' reload sounds back is not known.
- **Weapon registration.** Observed in test 5 on `mp_zombie_lab`: all 27 roster weapons registered. The mechanism is
  read from the game binary, not observed: a custom script's `main` and `init` run while the engine still registers a
  weapon on first use, so the shop's `getweaponbasename(<roster weapon>)` calls register every roster weapon that a
  loaded zone defines.
- **Duplicate definitions.** The Trident, Line Gun, Microwave and DLC ZM weapons are also defined by their own map
  zones, so on those maps the weapon is defined twice (later load wins, as with the patch zones). Expected to be
  harmless, not tested.
- **Cosmetic gaps.** Six trail materials (`smoke_trail_dear`, `_m990`, `_mors`, `_ohm_machinegun`, `_sniper`,
  `trail_epm3_plasma`) exist in no retail zone and fall back to the default material. The camo override above is empty,
  every weapon uses `defaulttracer`, and weapons with attachments play their base animations (no `animOverrides`).
  Fifteen sound aliases that the pack's weapons reference (for example `weap_de50_reload_npc`) are defined by no dumped
  zone, so the pack holds them as aliases without a sound file; they look like sounds only other characters play and
  were left alone.
- **Pool headroom.** The estimate is a model, not a measurement. By it the xanim pool is 90% full on `mp_zombie_lab`
  and 96% to 97% on `_ark`, `_brg` and `_h2o`, which the zones the model skips could push over, and `mp_zombie_h2o`
  is 25 slots over in loaded_sound (7,025 of 7,000; a lighter pack for that map is described under **Estimate**). The
  pack is also about 190 MB now, and whether the game has a size or memory limit for a mod fastfile is unknown. If a
  map stops loading again, note the exact error text (type and N); `watch-s1x-fds.sh` shows which zones were open.
  The options are in **Anim overrides** above.
