This repository contains custom Box Bot and Exo Zombies script tweaks, and the install paths below apply only to the listed files.

EMZ/EMP Zombies Nerf

`zm_all_weapon_damage.gsc` keeps Mk1 weapons at stock damage and applies a Cell 3 Cauterizer-style damage curve to its registered CB Servers S1x v0.0.4 Zombies internal weapon names, aliases, and online-confirmed variants from Mk2 through Mk25: `finalDamage = baseDamage + (baseDamage * 0.2 * (mark - 1))`.

Inside `s1`, create a `scripts` folder. For the script files documented below, create `mp` and `zm` inside `s1/scripts`; no `sv` folder is needed for those documented script files.

Place `autobots_combat_training.gsc` at `s1/scripts/mp/autobots_combat_training.gsc`.

Place `zm_emz.gsc` at `s1/scripts/zm/zm_emz.gsc`.
Place `zm_all_weapon_damage.gsc` at `s1/scripts/zm/zm_all_weapon_damage.gsc`.

Place `Bots.txt` (the custom bot names file) directly under `s1` at `s1/Bots.txt`, next to the `scripts` folder.
