# Auto Bots Exo Survival (S1x)

AI teammate package for **Call of Duty: Advanced Warfare Exo Survival** (not Zombies).

## Install

1. Copy `Auto-Bots-Exo-Survival` into your S1x directory.
2. Final script path should be:
   - `/s1x/Auto-Bots-Exo-Survival/scripts/auto_bots_exo_survival.gsc`

## Core dvars

- `scr_es_autobots_enabled` (0/1) - enable Exo Survival bots (`scr_es_autobots_enable` is also accepted for compatibility)
- `scr_es_autobots_count` (0-4) - desired bot count
- `scr_es_autobots_skill` (0.25-3.0) - bot skill scalar
- `scr_es_autobots_revive` (0/1) - revive downed allies
- `scr_es_autobots_buy` (0/1) - buy replacement weapons
- `scr_es_autobots_upgrade` (0/1) - buy Exo/armor/support/equipment upgrades
- `scr_es_autobots_restock` (0/1) - restock ammo
- `scr_es_autobots_equipment` (0/1) - use grenades/equipment contextually
- `scr_es_autobots_scorestreaks` (0/1) - use scorestreaks contextually
- `scr_es_autobots_exo` (0/1) - use Exo abilities contextually
- `scr_es_autobots_follow` (0/1) - regroup with living teammates

## Purchase tuning dvars

- `scr_es_autobots_weapon_cost`
- `scr_es_autobots_mystery_cost`
- `scr_es_autobots_ammo_cost`
- `scr_es_autobots_upgrade_cost`
- `scr_es_autobots_armor_cost`
- `scr_es_autobots_support_cost`
- `scr_es_autobots_equipment_cost`

Purchases are conservative: bots require affordability and attempt interaction. For positive-cost purchases, success is confirmed only when score drops after interaction; zero-cost interactions are treated as successful on interaction. The script never manually deducts score.
