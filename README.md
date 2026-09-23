This repository contains custom Box Bot and Exo Zombies script tweaks, and the install paths below apply only to the listed files.

EMZ/EMP Zombies Nerf

`zm_all_weapon_damage.gsc` keeps Mk1 weapons at stock damage and applies a Cell 3 Cauterizer-style damage curve from Mk2 through Mk25 to the weapons covered by its registered CB Servers S1x v0.0.4 Zombies internal names, aliases, and online-confirmed variants: `finalDamage = baseDamage + (baseDamage * 0.2 * (mark - 1))`.

Inside `s1`, create a `scripts` folder if you are installing the script files documented below. For those documented script files, create `mp` and `zm` inside `s1/scripts`; no `sv` folder is needed for them.

Place `autobots_combat_training.gsc` at `s1/scripts/mp/autobots_combat_training.gsc`.

Place `zm_emz.gsc` at `s1/scripts/zm/zm_emz.gsc`.
Place `zm_all_weapon_damage.gsc` at `s1/scripts/zm/zm_all_weapon_damage.gsc`.

Place `Bots.txt` (the custom bot names file) at `s1/Bots.txt`.
