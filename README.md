combat training custom difficulty and campaign to

EMZ/EMP zombies Nerf  

atlas 45 upgrade similar to the cell 3 culterizer 

make a folder in s1 call it scripts now in the scripts folder create 3 new folders 1 says mp 1 says sv 1 says zm

for autobots.gsc put in the mp folder

for auto_bots_zombies.gsc and zm_emz.gsc and
s1_scripts_zm_atlas45_damage.gsc put them in zm folder

for custom names put Bots.txt next to where you made the scrips folder

## Veteran difficulty dvar (combat training + campaign) and Elite guns

put s1_scripts_mp_veteran_difficulty.gsc in the mp folder (combat training / private match bots)

make a folder called sp in the scripts folder and put s1_scripts_sp_veteran_difficulty.gsc in it (campaign)

do not use autobots_combat_training.gsc at the same time, it forces its own bot settings

dvars (put them in the console or your config before loading a map):

- `scr_difficulty_override veteran` - `off`, `recruit`, `regular`, `hardened`, `veteran` or the new `veteran_plus`
  - combat training: bots use the exact private match profile (`veteran_plus` = veteran with tighter aim/faster firing)
  - campaign: forces the matching campaign difficulty (`veteran_plus` = veteran with more accurate enemies)
- `scr_difficulty_veteran_plus_scale 0.5` - MP only, 0.0 to 1.0, lower = harder veteran_plus bots
- `scr_difficulty_veteran_plus_accuracy 1.5` - campaign only, 1.0 to 3.0, enemy accuracy multiplier for veteran_plus
- `scr_ct_bot_elite_guns 1` - combat training bots spawn with Elite weapon variants
- `scr_ct_bot_elite_variants "7 8 9"` - which loot variant numbers (0-9) count as Elite
