# Auto Bots + BO2 Feel Zombies Mod

Source-only S1x Exo Zombies mod package that combines two ideas in one folder:

- **Auto Bots** for filling empty lobbies and helping in solo/co-op matches.
- **Black Ops 2 feel tuning** for round pacing, zombie health/speed, power-ups, crawler odds, and revive pacing.

## Folder layout

Place the whole `Auto-Bots-BO2-Zombies-Mod` folder into your S1x mod scripts/mods location using the same simple drop-in workflow described by this repository's root README.

Included script path:

- `scripts/zm/auto_bots_bo2_zombies.gsc`

## What the mod does

### 1) Auto Bots

When `scr_zm_autobots_enable` is enabled, the script keeps a configurable number of fake clients in the lobby and runs a lightweight bot loop that tries to:

- revive downed players and bots;
- move away from heavy zombie pressure when low on health/ammo;
- circle/train zombies when stable;
- buy nearby perks, doors, Pack-a-Punch, and exo utility when allowed by dvars;
- use frag/tactical equipment when surrounded.

### 2) BO2-style zombies feel

When `scr_zm_bo2_enable` is enabled, the script applies BO2-inspired tuning for:

- zombie health growth with easy-to-edit coefficients at the top of the GSC file;
- sprint round threshold and crawler chance;
- periodic special-round forcing logic;
- power-up weighting/duration defaults for insta-kill, double points, nuke, and related drops;
- revive/bleed-out pacing and point reward constants.

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

- `scr_zm_bo2_enable` - `0/1`, master switch for BO2-style zombie tuning.
- `scr_zm_bo2_sprint_round` - round where sprint behavior starts.
- `scr_zm_bo2_crawler_chance` - crawler spawn chance for later rounds.
- `scr_zm_bo2_special_round_interval` - how often special rounds repeat.
- `scr_zm_bo2_special_round_offset` - first special round number.
- `scr_zm_bo2_powerups_enable` - `0/1`, whether BO2-style drop weighting is applied.

## Tunable constants

The main gameplay constants are intentionally grouped at the top of `auto_bots_bo2_zombies.gsc`, including:

- health curve values;
- walk/run/sprint/crawler movement speeds;
- point rewards;
- revive and bleed-out timing;
- power-up durations and drop weights.

## Known limitations

- This repository does not include the game runtime or stock AW/S1x script set, so the script is provided as a self-contained source package and may need small hook-name adjustments if your modtools build uses different zombie/player notifies.
- Auto bots are implemented as a lightweight scripted behavior layer intended as a starting point for S1x modders, not as a replacement for a full engine-native navigation system.
- Because there is no local GSC compiler or Exo Zombies runtime in this repository, validation for this contribution is limited to source review and folder/package correctness.
