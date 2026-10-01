combat training custom difficulty and campaign to

EMZ/EMP zombies Nerf  

atlas 45 upgrade similar to the cell 3 culterizer 

make a folder in s1 call it scripts now in the scripts folder create 3 new folders 1 says mp 1 says sv 1 says zm

for autobots.gsc put in the mp folder

for auto_bots_zombies.gsc and zm_emz.gsc and
s1_scripts_zm_atlas45_damage.gsc put them in zm folder

auto_bots_zombies.gsc
- teammate Exo Zombies bot script for S1x
- place at s1/scripts/zm/auto_bots_zombies.gsc
- main dvars:
  - set scr_zm_autobots_enable 1
  - set scr_zm_autobots_count 3
  - set scr_zm_autobots_debug 0
  - set scr_zm_autobots_auto_ammo 1
  - set scr_zm_autobots_auto_progress 1
  - set scr_zm_autobots_auto_perks 1
  - set scr_zm_autobots_auto_revive 1
  - set scr_zm_autobots_map_hooks 0 (optional source-customization switch for map-specific override logic)
  - set scr_zm_autobots_scan_interval_ms 1000
- uses real Exo Zombies `iw5_*zm_mp` weapon ids already used elsewhere in this repo
- perk and revive behavior now try standard player natives first; exact success still depends on your S1x/AW build supporting those natives
- exo escape works by default through bot goal movement, while `scr_zm_autobots_map_hooks 1` is reserved for optional map-specific boost/jump overrides

for custom names, use the canonical path s1/Bots.txt
