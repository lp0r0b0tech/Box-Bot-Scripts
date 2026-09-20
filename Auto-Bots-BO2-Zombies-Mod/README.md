# Auto Bots + BO2 Feel Zombies Mod

Source-only **S1x** Exo Zombies mod package that combines two ideas in one folder:

- **Auto Bots** for filling empty lobbies and helping in solo/co-op matches.
- **Black Ops 2 feel tuning** for round pacing, zombie health/speed, power-ups, crawler odds, and revive pacing.

## S1x installation

Place the whole `Auto-Bots-BO2-Zombies-Mod` folder directly in your **S1x** directory so the final script path is exactly:

- `.../s1x/Auto-Bots-BO2-Zombies-Mod/scripts/auto_bots_bo2_zombies.gsc`

Included script path:

- `scripts/auto_bots_bo2_zombies.gsc`

## What the mod does

### 1) Auto Bots

When `scr_zm_autobots_enable` is enabled, the script keeps a configurable number of fake clients in the lobby and runs a lightweight bot loop that tries to:

- revive downed players and bots;
- move away from heavy zombie pressure when low on health/ammo;
- circle/train zombies when stable;
- buy nearby perks, doors, Pack-a-Punch, and exo utility when allowed by dvars;
- use frag/tactical equipment when surrounded;
- initialize S1x test clients directly from the script when auto-spawned so their bot loop does not rely only on a later connect notify.
- search interactables by broad AW/S1x-friendly trigger/name tokens instead of assuming a single exact targetname per map.

### 2) BO2-style zombies feel

When `scr_zm_bo2_enable` is enabled, the script applies BO2-inspired tuning for:

- zombie health growth with easy-to-edit coefficients at the top of the GSC file;
- preserved early/mid-round BO2-feel health growth that now eases into a late-round soft cap for round-100 play;
- sprint round threshold and crawler chance;
- periodic special-wave logic that speeds up and lightens zombies on configured rounds;
- polling fallbacks that rescan likely zombie and power-up entities if your S1x build uses different spawn notifies;
- power-up helper metadata/duration values grouped for build-specific S1x hook-up if you want to extend stock pickups;
- revive/bleed-out pacing plus BO2-style scripted point/reward constants for bot economy tuning.

## Dvars / settings

### Auto Bots

- `scr_zm_autobots_enable` - `0/1`, master switch for auto bots.
- `scr_zm_autobots_count` - target bot count to maintain.
- `scr_zm_autobots_skill` - bot movement/aggression scalar (`0.25` to `3.0`).
- `scr_zm_autobots_revive` - `0/1`, whether bots try to revive.
- `scr_zm_autobots_auto_buy_perks` - `0/1`, whether bots buy perks.
- `scr_zm_autobots_auto_buy_upgrades` - `0/1`, whether bots buy doors, PAP, and exo utility.
- `scr_zm_autobots_use_equipment` - `0/1`, whether bots auto-throw frag/tactical equipment.

### BO2 Feel Tuning

These defaults are applied with `setdvarifuninitialized`, so existing S1x dvar values are preserved and only missing values are initialized by the script. After startup, the script re-reads these dvars during its runtime loops, so changing them later updates bot logic periodically, while BO2 round-tuning changes fully settle on the next round retune or newly discovered zombie.

- `scr_zm_bo2_enable` - `0/1`, master switch for BO2-style zombie tuning.
- `scr_zm_bo2_sprint_round` - round where sprint behavior starts.
- `scr_zm_bo2_crawler_chance` - crawler spawn chance for later rounds.
- `scr_zm_bo2_special_round_interval` - how often special rounds repeat.
- `scr_zm_bo2_special_round_offset` - first special round number.
- `scr_zm_bo2_powerups_enable` - `0/1`, whether BO2-style power-up metadata/duration tuning is applied to discovered pickups.

## Tunable constants

The main gameplay constants are intentionally grouped at the top of `auto_bots_bo2_zombies.gsc`, including:

- health curve values;
- walk/run/sprint/crawler movement speeds;
- point rewards and bot wallet tuning;
- revive and bleed-out timing;
- simple token matching used to find AW/S1x perks, doors, PaP, exo stations, zombies, and power-ups;
- power-up duration metadata.

### Late-round health scaling

Normal zombie health is calculated in one shared path (`calculateBo2ZombieHealth`) that every tracked zombie spawn/retune route already uses:

1. rounds `1` through `ABZM_BO2_HEALTH_CURVE_ROUND` use the existing linear curve:
   - `ABZM_BO2_BASE_HEALTH + ((round - 1) * ABZM_BO2_HEALTH_INCREMENT)`
2. rounds after that continue the existing BO2-feel exponential growth:
   - previous round health `* ABZM_BO2_HEALTH_CURVE_MULTIPLIER`
3. after `ABZM_BO2_HEALTH_SOFTCAP_START_ROUND`, the curve eases toward `ABZM_BO2_HEALTH_SOFTCAP` by adding a bounded fraction of the remaining gap each round:
   - remaining gap `* ABZM_BO2_HEALTH_SOFTCAP_APPROACH_RATE`
   - clamped between `ABZM_BO2_HEALTH_SOFTCAP_MIN_STEP` and `ABZM_BO2_HEALTH_SOFTCAP_MAX_STEP`
4. `ABZM_BO2_HEALTH_CAP` remains the absolute defensive ceiling if you retune the constants.

Default late-round values:

- `ABZM_BO2_HEALTH_SOFTCAP_START_ROUND 35`
- `ABZM_BO2_HEALTH_SOFTCAP 15000`
- `ABZM_BO2_HEALTH_SOFTCAP_APPROACH_RATE 0.18`
- `ABZM_BO2_HEALTH_SOFTCAP_MIN_STEP 40`
- `ABZM_BO2_HEALTH_SOFTCAP_MAX_STEP 700`

With those defaults, the curve stays unchanged through round `35`, normal zombies settle near `15000` health by the late game, and special rounds still apply `ABZM_BO2_SPECIAL_HEALTH_SCALE` on top of that base (about `11250` health at round `100`). This package does not add separate round-based zombie damage scaling, so late-round survivability is governed mainly by the softened health curve plus the existing speed/special-round rules.

## Known limitations

- This repository does not include the game runtime or stock AW/S1x script set, so the script is provided as a self-contained source package and may need small hook-name adjustments if your modtools build uses different zombie/player/power-up notifies. Bot spending uses a script-side wallet in this source-only package; if you want stock HUD/persistence to match exactly, wire those point changes into your exact S1x runtime APIs.
- The script now avoids a custom `GetMode()` dependency and instead uses local zombies-context checks plus polling fallbacks, but exact AW/S1x hook names can still vary between builds and may need light retuning.
- Auto bots are implemented as a lightweight scripted behavior layer intended as a starting point for S1x modders, not as a replacement for a full engine-native navigation system.
- Because there is no local GSC compiler or Exo Zombies runtime in this repository, validation for this contribution is limited to source review and folder/package correctness.
