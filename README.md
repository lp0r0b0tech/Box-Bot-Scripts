combat training custom difficulty and campaign to

EMZ/EMP zombies Nerf  

atlas 45 upgrade similar to the cell 3 culterizer 

make a folder in s1 call it scripts now in the scripts folder create 3 new folders 1 says mp 1 says sv 1 says zm

for autobots.gsc put in the mp folder

for auto_bots_zombies.gsc and zm_emz.gsc and
s1_scripts_zm_atlas45_damage.gsc put them in zm folder

for custom names put Bots.txt next to where you made the scrips folder

BO2/EMZ Exo Zombies script: place `bo2_emz_combined_Version2.gsc` in
`s1/scripts/zm`. It supplies both `main()` and `init()` for script-loader
compatibility. It waits for the zombie gametype and uses S1's `level.wavecounter`
and enemy `level.agentarray` entries; bosses (including Oz and Goliath) are
excluded. Health starts at 150, increases by 100 through round 9, then by 10%
per round, capped at 30,000. Existing damaged zombies keep their health fraction
when the target changes. Speed uses the game's zombie speed-buff multiplier,
defaulting to 0.75, rather than changing player movement.

Optional server dvars: `scr_bo2_health_cap` (minimum 1) and
`scr_bo2_speed_cap` (clamped to 0.01–1). Both are read during play; clearing
either returns to its default. The EMZ proximity diagnostic is logging only,
not an EMP effect. Its default range is 128 game units; change
`level.emz_emp_range` or disable `level.emz_debug` in the script if desired.
This repository does not include the S1 runtime, so verify loader behavior,
buff effects, and boss identification in-game.
