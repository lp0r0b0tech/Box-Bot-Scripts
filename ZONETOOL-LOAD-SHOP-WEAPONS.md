# Loading the Exo Zombies shop weapons with a ZoneTool fastfile

> **Status: the pack loads and all 27 shop weapons register in the game (tests 5 to 8). Test 8 left three things open;
> the current build (build 10, for test 9) targets them and has not been tried in the game yet.**
> In the game, `+set fs_game mods/exo_weapons_all` did **not** mount the pack, while `+loadmod mods/exo_weapons_all`
> did (`s1x.exe` had `mod.ff` open). Zombies then stopped loading a map with `Exceeded limit of N '<type>' assets`
> until the animation pool (`xanim`, N = 5800) was relieved (see **Asset pool limits while playing**). Test 5 then
> loaded `mp_zombie_lab` with all 27 weapons registered, but the multiplayer weapons were red floating boxes (they
> still fired), the wonder weapons had no reload sound, and the Line Gun had no visible projectile and did no damage.
> The build tested next (test 6) packed the multiplayer weapons' real models (**Transient zones**), the assets the Line
> Gun's script needs (**Line Gun support**) and PCM instead of FLAC sounds (**FLAC sounds**). It loaded and registered
> all 27 weapons again, and the report named five problems: the optic attachments did not work right, the alternate
> fire modes of the Ohm and the XMG did not work, there were no Mk2 to Mk25 Pack-a-Punch camos, zombies did not go
> after the player (a leftover local test script, see [Not verified](#not-verified)) and the multiplayer weapons'
> ammunition was low next to the zombie weapons'. The build of test 7 kept the animation overrides of the optics and
> the alternate fire modes (**Anim overrides**), filled the first-person camo slot again (**Camos**) and raised the
> multiplayer weapons' ammunition (**Ammunition**). Its report did not mention those five items again, which does not
> show that they are fixed, and asked for four things: bullet and zombie-death effects for the Microwave Gun, working
> Mk2 and Mk15 camos on all weapons (the camo complaint had covered Mk2 to Mk25, so the other camos may work now),
> working melee on all multiplayer weapons with and without the exo suit, and a placeable Riot Shield on every Zombies
> map. Build 9 answered them with a reworked Microwave script (**Microwave Gun support**), a camo table meant to
> replace the retail one (**Camos**), the stock Zombies guns' melee data (**Melee**) and a Riot Shield script
> (**Riot Shield support**). Test 8 ran it: the pack mounted, `mp_zombie_lab` loaded and all 27 weapons registered, and
> the support log shows the Riot Shield being planted and picked up, and one later placement refused. The report left
> three things open:
> the XMG's melee transition is not right, the Ohm does not shoot in its alternate fire mode, and the animated Mk
> camos (Mk2 and Mk15) are still wrong on the shop weapons. The logs explain two of them. The shop read empty cells
> for camos 23 and 24 (`camo table row23= row24=`), because a pack cannot replace a camo table that a start-up zone
> defines; and the game refused the Ohm's alternate-fire loadout (`grant fallback: iw5_dlcgun2zm_mp_sensorheartbeatzm
> resolved to base ''`), because ZoneTool loses the integer parameters of every weapon attachment it dumps, so the
> pack's `sensorheartbeatzm` set all of its fields to 0 (**ZoneTool bugs**, **Anim overrides**). Build 10 repairs the
> attachments after the build (`fix-attachment-fields.py`), gives every weapon its own Mk2 and Mk15 materials instead
> of a table (`patch-camos.py`, **Camos**) and gives the XMG's two hands the exo punch as their swipe and kill
> animations (**Melee**). The shop (PR #14) changed with it and has to be installed together with the pack. None of
> this has been seen in the game.

The shop (`scripts/zm/s1_scripts_zm_exo_zombies_dlc_weapon_shop.gsc`) can only sell a weapon the game has
loaded. A GSC script cannot load fastfiles, and a zombies map's default fastfiles hold only a few of the shop's
27 weapons (on `mp_zombie_lab` the runtime log showed 1 of 27 registered). The fix is a fastfile that contains
all of them. This directory builds one with [ZoneTool](https://github.com/Joelrau/x64-zt):
`mods/exo_weapons_all/mod.ff`, which the client loads when graphics assets load (start-up or `vid_restart`) while
`fs_game` is `mods/exo_weapons_all`.

"The shop" here is the advanced version of that file: the one with the `mods/exo_weapons_*` pack logic that
writes `s1/dlcws_runtime_status.log` (added to the repository by PR #14). The shorter version that was on `main`
before has a different roster of `*zm_mp` weapons and none of this logic; the pack is built for the advanced roster.

Four support scripts in `scripts/zm/` go with the pack: `exo_zombies_linegun_support.gsc`,
`exo_zombies_microwave_support.gsc`, `exo_zombies_riotshield_support.gsc` and `exo_zombies_trident_support.gsc`. Each
makes one weapon (or the planting of the Riot Shield) work on the Zombies maps whose own scripts do not provide it; see
**Scripts** in the Quick start.

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

**Scripts.** The Line Gun, the Microwave Gun, the Trident and the planted Riot Shield work through script code that
stock Zombies provides only on some maps (for the shield, on none). Copy the scripts you want from `scripts/zm/` into
the game's `s1/scripts/zm/`: the shop (`s1_scripts_zm_exo_zombies_dlc_weapon_shop.gsc`, from PR #14; it may have any
file name there, but keep only one copy) and the four `exo_zombies_*_support.gsc` files. A support script starts the
missing code of one weapon on the maps that lack it, and does nothing on the map whose own script has it (Carrier for
the Line Gun, Infection for the Microwave Gun, Descent for the Trident) or when the pack is not loaded. Install the pack
and the scripts together: the Microwave script plays effects that only the current pack contains and raises a script
error against an older one, and the shop names the Mk2 and Mk15 camo materials that only the current pack defines (an
older pack has the marker weapon the shop checks for, but not those materials, so the shop would name materials that
nothing loads). To turn a support script off, set `scr_zm_linegun_enabled`, `scr_zm_microwave_enabled`,
`scr_zm_riotshield_enabled` or `scr_zm_trident_enabled` to 0 before the map loads. The Microwave Gun and Riot Shield
scripts log what they do to `s1/exo_zombies_support.log`; the Line Gun and Trident scripts print to the console.

To check it, start Exo Zombies and look at the last block of `s1/dlcws_runtime_status.log` (it is appended to on
every map start). A working setup logs `fs_game=mods/exo_weapons_all` and 27 `weapon=<id> registered` lines
(`pack=loaded` alone only means that at least one roster weapon is registered, which is also true without the pack).
After the block come `camo pack_materials=yes ...` (the shop found the pack's camo materials, see **Camos**), one
`camo 23 loadout ...` or `camo 24 loadout ...` line the first time a weapon gets a Mk2 or Mk15 camo and, only when
something was refused, `camo variant ... resolved to base ...` (the game dropped the Mk camo of that weapon, the plain
camo was used) or `grant fallback: ...` (the game did not resolve the loadout name to the weapon, the plain weapon was
given). To remove the pack, undo the launch option or delete `mods/exo_weapons_all`.

If a map stops loading with `Exceeded limit of N '<type>' assets`, an engine pool is full (N = 5800 is the animation
pool, `xanim`). The message only appears in the error box, so note the type and N, and see
**Asset pool limits while playing** in the technical notes.
`zonetool/watch-s1x-fds.sh` (Linux) logs the fastfiles `s1x.exe` opens, in order, which shows what was loaded when
it stopped.

The `.ff` is about 192 MB (150 MB in test 5, before the real models, the Line Gun's assets and the PCM sounds were
added) and consists of the game's own assets, so it is **not committed**. Build it with the steps below.

## What the pack contains

29 weapons: the 27 in the shop roster, plus two helpers for the Line Gun: `iw5_linegundamagezm_mp`, the weapon its
script fires for damage, and `iw5_dlcwscamo41_mp`, a marker weapon that script wants registered (see **Line Gun
support**). In total 7,372 assets: 46 attachments, 256 models with their 476 surfaces and 914 animations, 1,784 sounds
(924 sound aliases and 860 loaded sounds, 859 of them PCM and one empty), 192 effects, 909 images, 548 materials,
180 techsets and their shaders, 58 localized strings and one tracer (every weapon's tracer is set to
`defaulttracer`; of the weapons' attachment animation overrides only the 101 entries of the optics and alternate fire
modes are kept, see **Anim overrides**; the multiplayer weapons' melee data is the stock Zombies guns', see **Melee**).

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

Besides the weapons, the recipe names what the support scripts and the camos look up by name (the end of the CSV): six
animations and three effects of the planted Riot Shield, which only `common_mp` defines; eight effects and three sounds
of the Microwave Gun's cooking and death effects, which only `mp_zombie_brg` defines (they pull in six more models, a
flesh bubble and five gibs, with 12 surfaces, and the blood effects); and the 38 Mk2/Mk15 camo materials of 19 weapons,
which `patch-camos.py` generates (see **Camos**).

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
export GAME="${GAME:-$HOME/.local/share/Steam/steamapps/common/Call of Duty Advanced Warfare}"

# 1. Workspace: downloads ZoneTool, patches it (see "ZoneTool bugs"), symlinks the game's fastfiles
./setup-shadow-workspace.sh

# 2. Dump the base zones whole (one process each)
./run-zonetool.sh -dumpzone patch_common_mp
./run-zonetool.sh -dumpzone common_mp
./run-zonetool.sh -dumpzone techsets_common_core_mp
./run-zonetool.sh -dumpzone code_post_gfx_mp

# 3. Dump the zombie zones (only the asset types a weapon pack needs, one process per zone)
./dump-zones.sh mp_zombie_h2o mp_zombie_ark mp_zombie_brg common_zm_mp common_zombie_mp

# 4. Dump the display names of the Trident and Line Gun (they live in the per-map English zones) and the retail camo
#    tables, string tables of the English patch zone (they land in dump/eng_patch_code_post_gfx_mp/mp/camotable.csv and
#    camomaterialtable.csv; that zone defines fonts, so dump it in a process of its own, as here)
./dump-localize.sh eng_mp_zombie_h2o eng_mp_zombie_ark
printf 'dumpzone s1 eng_patch_code_post_gfx_mp stringtable\nquit\n' > "$WS/logs/cmd-camotable.txt"
./console-run.sh camotable "$WS/logs/cmd-camotable.txt"

# 5. Dump the stock transient zones that define the multiplayer weapons' viewmodels and worldmodels (52 zones, about
#    4 per process; ZoneTool merges all of them into dump/weapon_models). See "Transient zones".
./dump-tr-zones.sh \
  $(for w in ak47 dragunov fm4 leveraction m16 m1911 m1garand mp40 sten stg44; do echo mp_vm_${w}_tr mp_wm_${w}_tr; done) \
  $(for w in epm3 exoxmg m990 maaws mors pbw stingerm7 thor; do echo mp_{vm,wm}_${w}{,_2}_tr; done)

# 6. Add the pack source and the copied Magnetron string, then generate the rest of exo_patch. patch-weapons.py patches
#    the weapon JSONs: it blanks the broken camo field, points every tracer at defaulttracer, keeps only the
#    animOverrides entries of the optics and alternate fire modes the shop uses, raises the multiplayer weapons'
#    ammunition, gives them the stock Zombies guns' melee data (the XMG's two hands get the exo punch) and writes the
#    Line Gun's marker weapon. patch-sounds.py writes the sound alias overrides that cut take counts, and patch-camos.py
#    the Mk2/Mk15 camo materials of the 19 weapons whose retail materials no Zombies zone defines, with their state
#    files. All three resolve their paths relative to the workspace, so they run from there.
cp -r exo_patch "$WS/dump/"
cp exo_weapons_all.csv "$WS/zone_source/"
(cd "$WS" && python3 "$OLDPWD/patch-weapons.py" zone_source/exo_weapons_all.csv dump/exo_patch)
(cd "$WS" && python3 "$OLDPWD/patch-sounds.py" zone_source/exo_weapons_all.csv dump/exo_patch)
(cd "$WS" && python3 "$OLDPWD/patch-camos.py" dump/exo_patch)

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

# 10. Fill the first-person camo slots, which the build leaves empty (see "Camos"). It rewrites exo_weapons_all.ff in
#     place and keeps the unfixed build as exo_weapons_all.ff.nocamofix. Run it after the LAST build: build-verify.sh
#     deletes the .ff before it builds.
(cd "$WS" && python3 "$OLDPWD/camo-fix-ff.py" exo_weapons_all.ff --weapons-dir dump/exo_patch/weapons)

# 11. Put back the numbers ZoneTool loses in every weapon attachment it dumps and rebuilds (see "ZoneTool bugs"). It
#     rewrites exo_weapons_all.ff in place and keeps the previous file as exo_weapons_all.ff.noattfix; --check then
#     reads the raw bytes and exits with status 1 if any attachment still differs from the stock zone it came from.
#     Run it after step 10 and after the LAST build, like step 10.
(cd "$WS" && python3 "$OLDPWD/fix-attachment-fields.py" exo_weapons_all.ff --dump-dir dump \
  --recipe zone_source/exo_weapons_all.csv --game-dir "$GAME")
(cd "$WS" && python3 "$OLDPWD/fix-attachment-fields.py" exo_weapons_all.ff --dump-dir dump \
  --recipe zone_source/exo_weapons_all.csv --game-dir "$GAME" --check)
```

Step 8 and the last build of step 9 end with a verdict line such as
`exo_weapons_all: built 191956752 bytes; verify OK after 7372 assets; last=rawfile exo_weapons_all`. Step 10 makes the
file a little larger (191,956,921 bytes for that build) and step 11 once more (191,957,269 bytes); each prints its size
and sha256. Check the final file like any other build (**Checking a built pack**). The result is
`$WS/exo_weapons_all.ff`; install it with `./install-pack.sh`. A run that crashed or hit an engine "Fatal Error"
dialog says so in its verdict line and leaves a screenshot in `$WS/logs/fatal-*.png`.

## Technical notes

**Search order.** `addpath` lines in the CSV are searched top to bottom and the first directory holding an asset
wins. `exo_patch` is first (patched weapon JSONs, the copied Magnetron string, the sound alias overrides, the camo
materials, the PCM sounds), then the zombie map zones, then `patch_common_mp`, then `common_mp`.
`techsets_common_core_mp` and `code_post_gfx_mp` are needed as paths
because the shader and techset files `common_mp` references live in them. Without them the build dies on a missing
shader. `weapon_models` is last and holds the multiplayer weapons' models (see **Transient zones**).

**ZoneTool bugs, and the workarounds.**
- The FX writer emits a third decal material that does not exist and crashes `-buildzone`.
  `patch-zonetool.py` changes one byte of `zonetool.exe` (idempotent, keeps `zonetool.exe.orig`).
- The weapon writer copies `camoViewModelMaterialOverride` (the first-person camo material) as a raw pointer, which
  crashes the game while loading the weapon. `patch-weapons.py` therefore writes patched JSON copies with the field
  blanked, and `camo-fix-ff.py` fills the slot in the built zone afterwards (see **Camos**).
- The attachment dumper and parser mishandle the integer parameters of a weapon attachment's field list
  (`weaponattachment.cpp`). The parameter of the types `INT` (4) and `FLOAT32` (9) is read as a float when dumping
  (`static_cast<int>(parm.p_float)`, times 1000 for type 9) and written back as a float when parsing, but the engine
  stores a real int there: a stock `SET` of 12 is the int `0x0000000C`, which as a float is about 1.7e-44, so it dumps
  as 0 and the rebuilt attachment sets the field to 0, and a float multiplier added with `ADD` (1.5, say) is cut to a
  whole number. 23 of the pack's 46 attachments (99 fields) differed from their stock zones that way. One of them is the
  Ohm's alternate fire mode, `sensorheartbeatzm` (`shotCount`, `damage`, `fireTime` and the rest all set to 0): in
  test 8 the game refused the loadout built with it (`grant fallback: iw5_dlcgun2zm_mp_sensorheartbeatzm resolved to
  base ''`) and the shop gave the plain Ohm. That this is why the Ohm did not shoot in its alternate mode is a reading
  of the log and the data. `fix-attachment-fields.py` (step 11) puts the stock numbers back into the finished `.ff`
  (`s1ff.py` reads the stock zones); it refuses to write anything it cannot match to exactly one stock attachment. A
  dump of the repaired file still shows the zeros, because the dumper has the same bug, so check the result with
  `--check`.
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
that script; on the other maps `scripts/zm/exo_zombies_linegun_support.gsc` (deployed in `<game>/s1/scripts/zm/`, see
**Scripts**) ports it: each shot sends a line forward and damages every zombie it sweeps through, with a beam effect
and sounds of its own. It does nothing on Carrier, and it stays off (the console says `LineGunSupport: ... support stays
off`) unless `iw5_linegunzm_mp`, `iw5_linegundamagezm_mp` **and** `iw5_dlcwscamo41_mp` are all registered. When it is
on it loads three effects (`vfx/muzzleflash/dlc_zombies_linegun_laser`, `vfx/blood/dlc_zombie_line_gun_gib`,
`vfx/muzzleflash/dlc_zombies_drone_death`) and plays two sounds (`wpn_linegun_beam_hi`, `wpn_linegun_exp`). The test 5
pack had the two weapons but not the marker, the effects or the sounds, so the gun fired plain bullets: no visible
projectile and no damage. No stock zone defines the marker and the scripts only check that the name is registered, so
`patch-weapons.py` writes it as a copy of `iw5_linegundamagezm_mp`, and the recipe names the three effects and the two
sounds. The shop's native-camo check also reads the marker: it takes the marker as the sign that this pack, with its
camo materials, is installed (see **Camos**).

**Microwave Gun support.** The Microwave Gun's beam is script driven as well, and only `mp_zombie_brg` (Infection)
ships that script; elsewhere the weapon deals no damage by itself. `scripts/zm/exo_zombies_microwave_support.gsc` ports
the Infection behaviour: while fire is held every zombie in a thin beam (650 units, up to 850 while aiming, shortened by
walls) takes 30 damage per tick and a stacking slow (down to 60% to 40% speed for 3 to 10 s, by weapon level), the beam
drains a 900-unit battery shown on the HUD that max ammo, buying again or upgrading refills, and insta-kill makes it
an outright kill. Test 7 asked for the gun's bullet and zombie-death effects, which the previous version of the script
did not play. The current one adds what Infection plays: the flesh of a cooked zombie bubbles (five effects on its
spine, head and shoulders, under a bubbling loop), a zombie the beam kills pops into the microwave gib effect with the
pop sound and its body vanishes, and, as the other maps' impact table knows only concrete, the script plays the
flammable-surface and water impacts itself, about every 150 ms where the beam meets the world. "Bullet effects" is read
as these hit effects (the beam's laser, concrete impact and plain light are in the pack already); if the muzzle effects
are still missing in the game, the next step is to play the beam's visuals from the script too. The burger quest and
the cooked-zombies achievement stay Infection-only. The effects, the sounds and the gib models they pull in come from
the pack (end of the CSV), so install the pack and the script together: against an older pack the script raises a
script error. It does nothing on Infection or without the pack, `scr_zm_microwave_enabled` 0 turns it off, and it logs
the first use of every effect to `s1/exo_zombies_support.log`. Test 8 ran this version on `mp_zombie_lab`: the log has
the script's `loading effects`, `effects loaded` and `ready` lines (it got past loading its effects) but no line for an
effect that was played, and the report did not mention the gun, so whether the effects show is not known.

**Trident support.** `scripts/zm/exo_zombies_trident_support.gsc` does the same for the Trident, whose script only
`mp_zombie_h2o` (Descent) ships: every shot becomes a fast projectile (1,300 units per second for 2.5 s) that damages
each zombie it passes through (up to five), ricochets off walls and steers toward the best zombie in sight after every
bounce, for `scr_zm_trident_damage` (default 1200). Its trail is the pack's `vfx/trail/trail_trident`; the original
trail effects and projectile sounds are not in the pack. The console says `TridentSupport: ready.` when it is on, and
the script does nothing on Descent or without the pack.

**Riot Shield support.** Test 7 asked for a placeable Riot Shield on every Zombies map. Stock Zombies never starts the
deploy system: `_weapons.gsc` calls `maps\mp\_riotshield::init()` and `watchriotshielduse()` only outside Zombies. What
the placed shield needs is there or in the pack: the entity lists of all four maps (`mp_zombie_lab`, `_ark`, `_brg`,
`_h2o`) each name exactly one `riot_shield_collision` brush, `common_zm_mp` has its sounds, and its six animations and
three effects, which only `common_mp` defines, are named at the end of the CSV.
`scripts/zm/exo_zombies_riotshield_support.gsc` wraps the map's start hook, calls the stock `init()` and starts
`watchriotshielduse()` for every player. Nothing in Zombies sets the `riotshield_*` dvars the planted shield reads,
which would read 0 and destroy it on its first hit, so the script gives every one that is still 0 a default (health
1,000, the four damage scales 1, cleanup time 4). It does nothing without the shield weapon, on a map that already
starts the shield code or that does not have exactly one collision brush, and `scr_zm_riotshield_enabled` 0 turns it
off. A side effect of the stock code: while a player carries a shield, zombies cannot melee that player from the
shielded side (the front when it is held, the back when it is stowed). The first occurrence of each engine event the
planting relies on (`raise_riotshield`, `startdeploy_riotshield`, `deploy_riotshield`, `pickup_riotshield` and the
level's `riotshield_planted`) goes to `s1/exo_zombies_support.log`. Test 8 settled the first doubt: on `mp_zombie_lab`
the log shows the stock `init()` finishing, `watchriotshielduse` starting, and then `raise_riotshield`,
`startdeploy_riotshield`, `riotshield_planted`, a `deploy_riotshield` with a good placement, `pickup_riotshield` and a
later `deploy_riotshield` whose placement was refused (each kind of event is logged once, so the log does not say how
often it happened). The report did not mention the shield. Still not known: the dvars' real defaults, the input that
plants the shield (presumably fire) and why that placement was refused (the script only reads the event's `placed`
flag).

**FLAC sounds (a hypothesis).** ZoneTool embeds a loaded sound as FLAC when only `<name>.flac` exists in the search
paths and as PCM when a `<name>.wav` exists (`loaded_sound::parse` looks for the `.wav` first, in every search path). In
test 5 the wonder weapons (Line Gun, Microwave, Trident) had no reload sound. Every weapon-specific reload notetrack
alias of the Line Gun (8) and the Microwave (4) is FLAC, and so are 7 of the Trident's, while the multiplayer weapons'
reload aliases are PCM. A round-trip dump of the test 5 pack showed that data intact, and the wonder weapons' fire
sounds are FLAC too without anyone reporting them missing, so the cause is not proven. As an experiment
`flac-to-wav.py` decodes every FLAC loaded sound the pack uses into a WAV in `exo_patch/loaded_sound` (bit-exact:
`flac -d` checks the stream's MD5), so the pack now holds PCM only: 860 loaded sounds, 859 of them PCM and one empty.
If the reload sounds are still silent in the game, the cause is elsewhere (the aliases' settings, the loaded-sound
memory budget or the notetrack that plays them); none of that has been tested. The pack's growth from 150 MB to about
192 MB comes from the real models and the effects as well as from the PCM.

**Sound pool trims.** The loaded_sound pool (7,000) is the tightest one (see **Estimate**). By the model the build of
test 7 needed 7,025 on `mp_zombie_h2o`, 25 too many, because every pack sound that the base zones lack takes a slot,
even when the map's own zone defines the same sound. `patch-sounds.py` cuts the count with sound alias overrides that
win the search order: aliases that hold several takes of one sound (the Line Gun's chirps, coil buzzes and zaps, the
Ohm's laser, the M1 Irons' twang, the M1 Garand's ping, the Microwave's flesh explosion, the Trident's spark, the knife
stab) keep only their first takes, so the game plays the same take every time instead of one at random; the Line Gun's
beam spark drops the nine `general/electrical/spark_zap_NN` takes that only the pack carries; and the M1 Irons'
left-hand reload and foley sounds reuse the right hand's files. With the cuts, and with the Microwave's three new
sounds, the pack adds 131 loaded sounds to the 6,836 of the stock zones: 6,967 of 7,000 on `mp_zombie_h2o`, 33 free by
the model. Whether the cuts are audible, or the estimate right, has not been tested.

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
`animOverrides`, the replacement first-person animations a weapon plays when a given set of attachments is fitted
(the ADS-up/down of a scope, the switch into an alternate fire mode). With them the game stopped loading a map, so
the builds of tests 5 and 6 emptied every weapon's list (`numAnimOverrides` 0, which ZoneTool writes as no list, like
a stock weapon without overrides): 842 animations, 792 of them not already loaded by the base zones. Test 6 then
reported optics that did not work right and no alternate fire on the Ohm and the XMG. Neither has an alternate weapon
(`szAltWeaponName` is empty, `altWeapon` is 0, `altModeSameWeapon` is false and the pack holds no `alt_*` assets), so
the animations of their alternate mode (`altmodeAnim`, `altTime`) are stored only in `animOverrides`. That the emptied
lists are the cause is a reading of the data; the game has not confirmed it.

`patch-weapons.py` now keeps an entry when it names at least one attachment and every attachment it names is in the
weapon's set in `KEEP_ANIM_ATTACHMENTS`: the optic the shop fits to the weapon (it takes the optic of the stock Zombies
weapon that stands in for it, see `dlcws_upgrade_donor` in the shop) plus the attachments the game adds by itself.
Every other weapon keeps none:

| Weapons | Attachments an entry may name | Entries kept (of) |
|---|---|---|
| Ohm | `sensorheartbeatzm`, `opticstargetenhancer` | 24 (45) |
| XMG (Dual) | `akimboxmg` | 32 (32) |
| EPM3 | `variablereddot` | 5 (35) |
| SVO | `opticsacog2` | 5 (12) |
| M990 | `opticsacog2` | 3 (8) |
| MORS | `opticsacog2` | 2 (5) |
| Trident, Line Gun | `opticstargetenhancer` | 4 each (4 each) |
| MP443 | `opticstargetenhancer` | 2 (68) |
| DLC Weapon I, M1 Garand, Lever Action, STG-44, AK-47, M16 | `opticseotech` | 2 each (48, 64, 78, 89, 74, 73) |
| Microwave, MP40, Sten, Repulsor | `opticsreddot` | 2 each (36, 44, 48, 40) |

That is 101 entries on 19 weapons, using 109 animations, 74 of them new to the pack. With the Riot Shield's six
placed-shield animations, the pack now holds 914 animations, 868 of them not already loaded by the base zones. By the
estimate below that leaves 497 free `xanim` slots on `mp_zombie_lab` and 86 to 166 on the other maps (ark 86, brg 166,
h2o 93). The 1911, DLC Weapon III, the Blunderbuss and
the Line Gun's helper weapons keep nothing, and the Thor, Riot Shield, MAAWS, Stinger M7 and MDL have no overrides at
all. If a pool is still full, trim `KEEP_ANIM_ATTACHMENTS` (the EPM3, SVO and Ohm entries are the cheapest to lose),
then blank the left/right-hand animation sets of every weapon except `iw5_exoxmg_mp` (the only shop weapon with an
akimbo variant; 122 fewer animations) and build a pack per map without the weapons that map defines itself.

Test 8 showed that the kept entries were not enough for the Ohm. The shop builds the Ohm's loadout from the attachment
`sensorheartbeatzm` (the Zombies alias of its alternate fire mode) and an optic; the game resolved that name to no
weapon (`getweaponbasename` returned an empty string), so the shop logged `grant fallback` and gave the plain Ohm, which
has no alternate mode. The XMG's dual loadout resolved (no fallback line). The cause is read as the zeroed fields of the
pack's `sensorheartbeatzm` (see **ZoneTool bugs**), which `fix-attachment-fields.py` restores; the animation entries
did not decide it. If the `grant fallback` line for the Ohm is still in the log after a retest, what is left to try is
the 21 entries that were dropped for the Ohm (24 of 45 are kept), the Ohm's own tracer (`ohm_machinegun`, now
`defaulttracer`) and writing the alternate mode's values into the weapon JSON itself.

**Camos.** A weapon's camo is applied over one material of its model, named by `camoWorldModelMaterialOverride` (world
model) and `camoViewModelMaterialOverride` (first-person model); that is a reading of the field names and the stock
data. In the stock zones every weapon that names the first names the same material in the second
(`iw5_gm6loot7_mp`, which is not in the pack, is the one exception). The ZoneTool weapon writer never converts the
second field (see **ZoneTool bugs**), so the weapon JSON must leave it blank, and a blank field means no camo on the
first-person weapon: test 6 had no Mk2 to Mk25 camos. `camo-fix-ff.py` (step 10) repairs the finished `.ff`. It unpacks
the zone (a 44-byte header, one 24-byte entry per stream file, then a single zlib stream), finds each `WeaponDef`
(0xDE8 bytes; the world override's asset reference is at offset 0x38, the first-person one at 0x40), copies the
reference over, recompresses the zone and fixes the lengths in the header. It refuses to write anything unless it
finds each weapon whose patched JSON has a world override exactly once (28 of the 29: the Riot Shield has none).
ZoneTool reads the repaired file back (a dump of it loads) and names the same material in both fields for all 29
weapons. Test 7, the first with this repair, reported only the Mk2 and Mk15 camos (camos 23 and 24, `toxictiger` and
`infected`) as broken, no longer the whole range, which suggests that the repair worked for the others (an inference:
the report does not say so).

Camos 23 and 24 are a separate case. The engine finds a camo by name in `mp/camotable.csv` (no header row; column 1 is
the name, column 8 a global material, column 10 an index into the weapon's row of `mp/camomaterialtable.csv`). The
retail rows 23 and 24 have no global material, only the index (4 and 5), so every weapon needs its own Mk2 and Mk15
material, listed in the per-weapon table and loaded by a zone. Of the 26 weapons of the pack that have a row there, 13
have blank cells (the Thor, MAAWS, M990, Stinger M7, MP443, EPM3, MDL, MORS, XMG, M1 Garand, Lever Action, Repulsor and
Sten), 6 name materials that none of the dumped zones defines (the 1911, AK-47, M16, MP40, STG-44 and SVO), and only 7
(DLC Weapons I and III, the Ohm, the Blunderbuss, the Line Gun, the Microwave and the Trident) name materials that
`common_zm_mp` or `patch_common_zm_mp` define, so by the data 19 weapons had nothing to show. Until build 8 the shop's
check for the two camos (`level.dlcws_nativeCamosReady`) wanted the XMG's cells filled in, which the stock table leaves
blank, so it never passed, and the shop gave every weapon outside `dlcws_camo_has_variants` the previous camo at those
two steps.

Build 9 tried to fill the gap with a camo table of its own in the pack (the CSV line `stringtable,mp/camotable.csv`;
`exo_patch` is first in the search order, so by name it should win) whose rows 23 and 24 named a global material, and
the shop read the two names back from it. Test 8 shows that this did not work: the shop logged
`camo table row23= row24= mk2_mk15_on_imported_weapons=no` (empty cells), so the imported weapons wore the previous
camo at those two levels. That is a reading of one log line, but it fits the engine's rule that the first copy of an
asset name wins: both tables (`camotable.csv`, `camomaterialtable.csv`) are assets of a start-up zone, so a copy in the
pack is dropped. A pack can only add assets whose names no start-up zone defines, and the game finds a camo's material
by the name the table gives it.

Build 10 therefore leaves the tables alone and defines, in the pack, materials under names the tables already hold.
`patch-camos.py` writes 38 of them (the recipe names them) for the 19 weapons the retail Zombies zones leave without
Mk2 and Mk15 materials; the seven Zombies guns need nothing, and the Riot Shield has no row and wears no camo:

| Weapons | The pack defines | The shop asks the game for |
|---|---|---|
| 7 Zombies guns: DLC Weapons I and III, Ohm, Blunderbuss, Line Gun, Microwave, Trident | nothing, their zones have the materials | camos 23 and 24, as the levels give them |
| 6 with names but no materials: 1911, AK-47, M16, MP40, STG-44, SVO | `m/<stem>_toxictiger` and `m/<stem>_infected` (12), the names the table has | camos 23 and 24 |
| 13 with blank cells: Thor, MP443, EPM3, Lever Action, M1 Garand, MAAWS, MDL, M990, Repulsor, Stinger M7, Sten, MORS, XMG | `m/<stem>_reptile` and `m/<stem>_lava` (26), the names of the camo01 and camo04 cells, which only the multiplayer zones define | camo 19 where the level says 23 (Mk2) and camo 22 where it says 24 (Mk15), `dlcws_mk_camo` |

No level of `mp/zmweaponlevels.csv` uses the camos 19 to 22, so those weapons never wear the Exo looks the names belong
to. Each new material is the weapon's multiplayer material `m/<stem>_reptile` (from `patch_common_mp`) with the three
decal textures of its camo (colour, normal, specular) replaced by the retail toxic tiger or infected ones, which
`common_zm_mp` defines (`camo_xom1_toxic_tiger_col` and `camo_xom1_infected_col` with their normal and specular maps).
The weapon's own decal mask and glow map, the flow maps and the techset stay the donor's, so the pattern is the retail
one on the donor's layout, animated as the donor's techset animates it, without the retail per-weapon glow map. The
retail infected material also has another techset and a dimmer glow, which is not reproduced, because the
constant-buffer file (`.cbt`) of a material holds its constants at unaligned offsets and cannot be regenerated; each
new material takes the donor's state files (`stateinfo`, `statebits`, `statebitsmap`, `cbi`, `cbt`) verbatim.
`patch-camos.py` rebuilds the retail `m/ak12_toxictiger` and `m/ak12_infected` from `m/ak12_reptile` as a self test and
checks that only the glow map, the mask, the techset and two constants differ.

The shop treats the two camos as available (`level.dlcws_nativeCamosReady`) when the pack is loaded and its marker
weapon `iw5_dlcwscamo41_mp` is registered, so **the pack and the shop script must be installed together**: a pack from
before build 10 has the marker but not these materials, so the new shop would ask it for camos that are not there.
Without the marker the imported weapons wear the previous level's plain camo (the Zombies guns keep 23 and 24). The
shop logs to `dlcws_runtime_status.log`:
`camo pack_materials=yes|no weapons_without_a_camo_material_in_the_table: ...` (the weapons
whose table cell for the camo it would ask for is blank; `none` is expected), the first loadout it builds for each of
the two camos (`camo 23 loadout ...`), `camo variant ... resolved to base '...', using ...` when the game refuses a Mk
loadout name and the shop gives the plain camo instead, and every `grant fallback`. Not known: whether the engine
applies the camo 19 and camo 22 materials in Zombies the way it applies 23 and 24, how the new materials look on each
model (a dump shows the files, not the picture), and whether the repeated constant-buffer ID words of the derived
materials do harm. If they misbehave, setting `level.dlcws_nativeCamosReady` to false in `dlcws_loadout_init` gives
every imported weapon the previous level's camo again, at the price of the Mk2 and Mk15 look.

**Ammunition.** The multiplayer weapons keep their multiplayer ammunition (the Thor starts with 16 and holds 48 at
most, the MAAWS has one rocket, the 1911 starts with 28 and holds 42), well below the stock Zombies weapons of their
class, and the shop has no ammunition logic of its own. `patch-weapons.py` (`AMMO_TARGETS`) raises `startAmmo`
(magazine plus reserve at the start) and `maxAmmo` (the reserve) of 15 of them to the values of the Zombies weapon
that matches each one, in whole magazines; values are only ever raised and `clipSize` is not touched. In the stock
scripts, ammo purchases and refills go up to `maxAmmo` (`weaponmaxammo`, `givemaxammo`):

| Weapon | start / max (was) | Zombies weapon it follows (start / max) |
|---|---|---|
| Thor | 24 / 48 (16 / 48) | `gm6zm` 24 / 48 |
| MAAWS | 2 / 10 (1 / 1) | `mahemzm` 2 / 10 |
| M990 | 24 / 80 (20 / 80) | `gm6zm` 24 / 48 |
| Stinger M7 | 8 / 40 (8 / 16) | `tridentzm` 5 / 40 |
| MDL | 12 / 36 (12 / 12) | no Zombies weapon: six magazines of reserve |
| 1911, MP443 | 42 / 70 (28 / 42), 48 / 72 (48 / 60) | `titan45zm` 40 / 65 |
| AK-47, STG-44 | 120 / 210 (120 / 180) | `ak12zm` 120 / 210 |
| Lever Action, M1 Garand | 80 / 120 (64 / 80, 40 / 48) | `m182sprzm` 80 / 120 |
| MP40, Sten | 128 / 224 (128 / 192) | `sn6zm` 128 / 200, `mp11zm` 128 / 220 |
| Repulsor | 140 / 245 (140 / 192) | `hmr9zm` 140 / 200 |
| XMG (Dual) | 400 / 350 (400 / 300) | `asawzm` 200 / 350 |

The M16 (180 / 225), the SVO (30 / 60) and the MORS (24 / 48) are already at the level of their Zombies weapons, the
Riot Shield stays at 1 / 1, and the EPM3 and the Microwave run on a heat bar (`ammoPerShot` 0), so none of them
changes. The new values have only been checked in a dump of the pack, not in the game.

**Melee.** Test 7 reported the melee of the multiplayer weapons as broken, with and without the exo suit. What breaks
is not known; what follows is a hypothesis from the data and has not been tried in the game. 33 of the 35 stock
Zombies guns in the dumped zones (`iw5_*zm_mp`, every class from pistols to launchers) carry one melee data set: the
tactical knife (`knifeModel` `vm_mp_tactical_knife`, `worldKnifeModel` `npc_mp_tactical_knife`), the first-person
animations `vm_knife_melee_slice_l` (swipe), `vm_knife_melee_stab_l` (kill, also against a crouching victim, which five
of the guns leave empty), `vm_exo_melee_hook_r` and `vm_exo_melee_uppercut_l` (the suit's standing and crouching melee),
and the timers `meleeChargeTime` 1200, `meleeDelay` 80 and `meleeChargeDelay` 100 (the exceptions are the exo minigun
and the Juggernaut rockets). The pack's multiplayer weapons kept the multiplayer set: no knife model (or the combat
knife), `viewmodel_knife_melee_*` animations, `vm_exo_melee_punch` for the suit, and the timers 1160, 130 and 160. That
may not display properly in Zombies: the swipe without the suit would play with no knife in the hand, and the punch
with the suit is the multiplayer animation. `zm_melee_profile()` in `patch-weapons.py` gives each multiplayer weapon
the Zombies set, field by field and only where a value equals the multiplayer one; the pistols (`weapClass` 5) get the
animations in their left and right-handed sets too, as the stock Zombies pistol does. The Riot Shield (it bashes with
its own animations), the stock Zombies guns and `hasTransientModels` (the models come from the pack and show correctly)
stay as they are. In a dump of the finished pack, 20 of the 28 weapons other than the shield match the Zombies set in
all ten fields checked (the two knife models, five animations and three timers), 7 match except for an empty
crouching-victim slot (the EPM3, M990, MAAWS, MDL, Stinger M7, Microwave and Trident),
and the XMG keeps `vm_exo_melee_punch` in its swipe and kill slots. The damage side does not depend on the weapon
(`all_weapon_damage.gsc` makes every `MOD_MELEE` hit a one-hit kill), so if melee is still broken the next thing to try
is `hasTransientModels` (true on the pack's XMG, false on the stock Zombies guns).

Test 8 (build 9, with that profile) no longer mentioned the melee of the other weapons, which suggests but does not
show that the Zombies set works for them, and reported that the XMG has no proper melee transition. The XMG is the
exception to the profile because the shop sells it only dual-wielded (the variant with the `akimboxmg` attachment). The
`animOverrides` kept for it force `vm_exo_melee_punch` into the alternate melee slots of both hands, so the hook and the
uppercut of the Zombies set would never play in that state and the tactical knife would hang in the hand during a punch;
`patch-weapons.py` therefore leaves its melee data alone (`DUAL_MELEE_WEAPONS`). What the build 9 pack left empty were
the swipe and kill slots (`MELEE_SWIPE`, `MELEE_FATAL`) of its left-handed and right-handed animation sets, which the
stock Zombies dual-wield gun (`iw5_sac3zm_mp`) fills with its knife swipe and stab. Whether the engine falls back to the
first set for an empty slot or plays nothing is not known. Build 10 fills those slots with the same punch
(`hand_melee_anims()`; in a dump of the pack the swipe and kill slots of both hands now name `vm_exo_melee_punch`). The
report does not say what looks wrong (no animation, a wrong one, a stray knife, the guns snapping into place, or the
transition out of the exo lockdown); if it still does after build 10, that description is the next input, and the stock
dual-wield gun's knife set is what to try. Not tried in the game.

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
| `mp_zombie_lab` | 4,435 to 5,303 (91%) | 5,554 to 5,685 (81%) | 13,364 to 13,366 (98%) |
| `mp_zombie_ark` | 4,846 to 5,714 (99%) | 6,065 to 6,196 (89%) | 13,433 to 13,435 (99%) |
| `mp_zombie_brg` | 4,766 to 5,634 (97%) | 5,990 to 6,121 (87%) | 13,410 to 13,412 (99%) |
| `mp_zombie_h2o` | 4,839 to 5,707 (98%) | 6,836 to 6,967 (**99.5%, 33 free**) | 13,421 to 13,423 (99%) |

Every other pool stays under 90% (`equipsndtable` is 1 of 1 without the pack, and the pack adds none). The fullest are
`techset` (77% on `mp_zombie_lab`, 86% on `_ark`, 50% and 54% on `_brg` and `_h2o`) and `fx` (71% to 84%); `material`
is at 61%, 67%, 45% and 47% in that order and `image` at 54% to 55%. Build 10's camo materials added 36 materials, 24
images, 15 pixel shaders and one techset to the pack. The same model puts the test 3 and 4 builds at 102%
(`mp_zombie_lab`) to 109% (`_ark`, `_h2o`) of the xanim pool, which is what the
game reported. The animations kept by **Anim overrides** are what moved the xanim column (it was 90% and 96% to 97%
before): 497 free slots on `mp_zombie_lab` but only 86 (`_ark`), 166 (`_brg`) and 93 (`_h2o`) on the others, and
up to 5,760 of 5,800 (99%) on `_ark` if the engine kept both copies of an animation that the base zones define too.
loaded_sound is the tightest: `mp_zombie_h2o` needs 6,967 of 7,000 if a pack asset that the first four zones define
costs nothing, as modelled, and up to 7,696 (110%, over the limit) if the engine kept both copies; the cuts of **Sound
pool trims** are what brought it under (the build of test 7 needed 7,025). The pack's copies of the sounds of the
weapons that map defines itself (`dlcgun1zm` to `4zm`, `tridentzm`) are charged in both figures: 94 of the pack's 860
loaded sounds are also defined by `mp_zombie_h2o`. A pack for that map without those five weapons (delete their
`weapon,` lines) would therefore free up to 94 slots by the model. Only the xanim limit has been confirmed in the game,
so the loaded_sound figures are a prediction; only `mp_zombie_lab` and `mp_zombie_brg` have been played with the pack.

**Checking a built pack.** `-verifyzone` only shows that the zone loads inside ZoneTool, so dump the finished pack and
look at what it holds. Copy it to another name first (`dumpzone` needs a `dump/<zone>` that does not exist yet), write
a command file of `loadzone common_mp`, `loadzone techsets_common_core_mp`,
`dumpzone s1 <copy> weapon,attachment,xanim,sound,loaded_sound,fx,xmodel,xmodelsurfs,material` and `quit`, and run
`console-run.sh <tag> <command file>`; it takes about 20 seconds (`assets=0` in the verdict is normal for a dump, look
at `dumped=1`). Dumping a zone that the same process has already loaded never finishes. Do this after step 10, so that
the dump is of the file that gets installed. For the current pack the counts of that dump equal the build log's (29
weapons, 46 attachments, 256 xmodels, 476 xsurfaces, 914 xanims, 192 fx, 924 sound aliases, 860 loaded sounds of which
859 are `.wav`); it holds the marker weapon, the Line Gun's effects and `wpn_linegun_*` aliases, the 38 camo materials
of **Camos** (under `materials/m/`) and no camo table, and 160 of the 196 decoded WAVs byte for byte (the other 36 are
not used by the current pack). In the weapon JSONs the first-person camo field names the same material as the world one
in all 29 weapons (the Riot Shield has none), 101 `animOverrides` entries are left on the 19 weapons of **Anim
overrides**, `startAmmo` and `maxAmmo` are the values of **Ammunition**, and the XMG's swipe and kill slots of both
hands name `vm_exo_melee_punch` (**Melee**). The attachments are the exception: the dumper loses their integer
parameters again (**ZoneTool bugs**), so a dump shows the zeros that the repair removed, and
`fix-attachment-fields.py --check` is the test for them. A byte comparison of its `.xsb` surface files with the
stock dumps shows differences that are not defects: ZoneTool's dumper writes an array that lies inside an earlier one as
a 9-byte reference record instead of the data, a stock surface shares its triangle indices that way, and the pack stores
each array separately, so the pack's file is `6 * triangles - 3` bytes larger per such surface (for example 1,858
triangles, +11,145 bytes). With the references resolved and pointer fields ignored, all 464 surfaces of the test 6 pack
match the stock dump they were taken from (checked with a throwaway script that is not part of this directory); the
dump of the current pack holds those 464 files with the same sizes, plus 12 new surfaces of the gib and bubble models
that the Microwave Gun's effects pull in.

**Running ZoneTool headless under Wine.** `run-zonetool.sh` uses DXVK's `d3d11`/`dxgi`, a private headless
`gamescope` for Wine's display, a copied `fileSysCheck.cfg`, and a memory cap through `systemd-run`.
`zone/` must not exist in the workspace (builds land in the workspace root). `console-run.sh` feeds a command file
to ZoneTool's console (lines end in CR) and reports `dumped=`, `fatal=` and `crash=` in one verdict line;
the wrapper's own exit status is always 0. A dump is complete when the log has `Zone "<name>" dumped.` and the
CSV's size is not a multiple of 4096. `-verifyzone` doubles as a cheap asset lister (`Loading asset "x" of type y.`).

## Not verified

- **In-game behaviour.** Eight tests so far, all through the CB Servers launcher. Test 1 started without `fs_game`
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
  Test 6 used the build with real models, the Line Gun's marker weapon and PCM sounds (and still empty
  `animOverrides`): the pack mounted, `mp_zombie_lab` loaded without a limit error and all 27 weapons registered. The
  report was five items: optics that did not work right, no alternate fire on the Ohm and the XMG, no Mk2 to Mk25
  camos, zombies that did not go after the player, and a request for more ammunition on the multiplayer weapons. It did
  not mention the red boxes, the reload sounds or the Line Gun's beam and damage, so whether those are fixed is not
  known. The zombies that ignored the player were caused by a local diagnostic script, deployed next to the shop and
  not part of this repository, that set `zombiesignoreme`; it was taken out of the game's `scripts/zm` folder before
  the next build. Test 7 used build 8 (the restored `animOverrides` entries, the camo slot filled by hand, the raised
  ammunition, no diagnostic script): the maps loaded and were played, and the report asked for four new things: the
  Microwave Gun's bullet and zombie-death effects, the Mk2 and Mk15 camos on every weapon, melee on the multiplayer
  weapons with and without the suit, and a Riot Shield that can be placed on every Zombies map. It did not mention the
  optics, the alternate fire, the zombies or the ammunition again, which suggests but does not show that those are
  fixed. Test 8 used build 9 (the Microwave script with effects, the camo table, the stock Zombies guns' melee data and
  the Riot Shield script): the pack mounted, `mp_zombie_lab` loaded, all 27 weapons registered, and the support log
  shows a Riot Shield that was planted and picked up. The report left three things open: the XMG's melee transition,
  the Ohm's alternate fire and the animated Mk camos, and the shop's log explains two of them (`camo table row23=
  row24=` and `grant fallback: iw5_dlcgun2zm_mp_sensorheartbeatzm resolved to base ''`). It did not mention the
  Microwave Gun's effects, the melee of the other weapons or the Riot Shield again. The log's `fs_game=` and `pack=`
  fields show whether the shop ran against the pack.
- **Build 10 has not been tried (test 9 is pending).** What this guide says about its three changes comes from dumps
  of the finished pack, from `fix-attachment-fields.py --check` and from the scripts, not from the game. The Ohm: the
  repair of `sensorheartbeatzm` is only checked in the file, and that its zeroed numbers made the game refuse the
  loadout is a reading of the log; if the shop logs `grant fallback: iw5_dlcgun2zm_mp_sensorheartbeatzm` again, the
  repair did not help and the options are under **Anim overrides**. The camos: whether the engine applies the camo 19
  and 22 materials to the 13 imported weapons of class C in Zombies, and how the derived materials look, are not known;
  after a retest these lines of `dlcws_runtime_status.log` show what the shop chose: `camo pack_materials=...`,
  `camo 23 loadout ...` and `camo variant ... resolved to base ...` (**Camos**). The XMG: the swipe and kill slots of
  its hands are a guess at what its transition lacks, and the report does not say what looks wrong (**Melee**). The
  earlier fixes are in the same state: the melee data of the other weapons is a hypothesis about what breaks
  (**Melee**); the Microwave Gun's effects are the ones Infection plays, started from the support script, "bullet
  effects" is an interpretation, and test 8's log has no line for a played effect (**Microwave Gun support**); the
  placeable Riot Shield was planted and picked up in test 8, but how it plays was not reported (**Riot Shield
  support**); the optics and the alternate fire modes are the restored `animOverrides` entries, and the XMG's alternate
  fire was not mentioned again after test 6 (**Anim overrides**); the first-person camo slot is filled by hand in the
  finished file and the raised ammunition is only checked in the dump (**Camos**, **Ammunition**); and the real models
  are packed and every surface matches its stock dump, but how the weapons render is not known, as the reports of tests
  6 to 8 do not mention the red boxes. The Line Gun script finds all three weapons, the effects and the sounds it needs,
  but whether it deals damage and shows the beam is not known (after a retest, look for the console line
  `LineGunSupport: ready.`; `support stays off` means it still lacks a weapon). The PCM sounds are an experiment:
  whether they bring the wonder weapons' reload sounds back is not known. After the next test read
  `s1/dlcws_runtime_status.log` and `s1/exo_zombies_support.log`.
- **Weapon registration.** Observed with the pack loaded in five runs, four on `mp_zombie_lab` and one on
  `mp_zombie_brg`: all 27 roster weapons registered in each. The mechanism is read from the game binary, not observed:
  a custom script's `main` and `init` run while the engine still registers a weapon on first use, so the shop's
  `getweaponbasename(<roster weapon>)` calls register every roster weapon that a loaded zone defines.
- **Duplicate definitions.** The Trident, Line Gun, Microwave and DLC ZM weapons are also defined by their own map
  zones, so on those maps the weapon is defined twice (later load wins, as with the patch zones). Expected to be
  harmless, not tested.
- **Cosmetic gaps.** Six trail materials (`smoke_trail_dear`, `_m990`, `_mors`, `_ohm_machinegun`, `_sniper`,
  `trail_epm3_plasma`) exist in no retail zone and fall back to the default material. Camos 23 and 24 of the 19
  imported weapons are the retail pattern on the multiplayer donor's layout, without the retail per-weapon glow map
  (**Camos**), every weapon uses `defaulttracer`, and attachments other than the optics and alternate fire modes of
  **Anim overrides** play their base animations. Fifteen sound aliases that the pack's weapons reference (for example
  `weap_de50_reload_npc`) are defined by no dumped zone, so the pack holds them as aliases without a sound file; they
  look like sounds only other characters play and were left alone.
- **Pool headroom.** The estimate is a model, not a measurement. By it the xanim pool is 91% full on `mp_zombie_lab`
  (497 free slots) and 97% to 99% on `_ark`, `_brg` and `_h2o` (86 to 166 free), which the zones the model skips could
  push over, and `mp_zombie_h2o` has 33 free slots in loaded_sound (6,967 of 7,000), or 110% of the pool if the engine
  keeps both copies of a sound the base zones define too (**Sound pool trims**, **Estimate**). Only `mp_zombie_lab` and
  `mp_zombie_brg` have been played with the pack, and not yet with the current one; `_ark` and `_h2o` never. The pack
  is also about 192 MB now, and whether the game has a size or memory limit for a mod fastfile is unknown. If a map
  stops loading again, note the exact error text (type and N); `watch-s1x-fds.sh` shows which zones were open. The
  options are in **Anim overrides** above.
