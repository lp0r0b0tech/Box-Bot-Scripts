## S1x Exo Zombies teammate bots

For the S1x client, place `exo_zombies_teambot_max.gsc` directly in
`<game folder>/s1x/scripts/`. Do **not** put this file in `s1/scripts/zm/`
or a subfolder of `s1x/scripts/`: the public S1x loader scans the top-level
`scripts` folder. Remove older copies of this bot script, keep the `.gsc`
extension (not `.gsc.txt`), and restart the game.

Start a local Exo Zombies match and use `spawnbot 3` as usual. An on-screen
`EZTB active - teammate bots: 3` message confirms the script is running and
recognizing three bots. The console also prints `[EZTB] main loaded` and
individual bot detection messages. If no message appears, check the loader's
`script compile error` output and the installation path before changing settings.

Only this bot file is required; leave `allweapondamage_Version2.gsc` unchanged.
The script is restricted to the Zombies gametype and does not spawn extra bots.

Features:
- Veteran difficulty plus zero bot aiming error and reaction delay.
- 30,000 health restored while alive and not downed.
- Native Exo suit and upgrades, reapplied after loss; Exo Revive is skipped
  when the game does not register it (hard mode). Grants do not consume the
  human players' points or limited station purchases.
- CEL-3 Cauterizer Mk25 with native attachments/camo and replenished ammo,
  provided the map registers that weapon. Atlas 45 and CEL-3 hits use lethal
  damage against ordinary zombies; native boss immunities remain intact.
- Bots approach reachable, powered doors they can afford and pay with their
  own points. They prioritize nearby downed teammates and hold use to revive.
  Movement depends on the map's navigation and blocked targets time out.

Native Exo equip animations take several seconds after a bot spawns. Watch
`[EZTB] Granted ...` and `[EZTB] CEL-3 Mk25 equipped ...` messages in the console.

The script was compiled with `gsc-tool -m comp -g s1 -s pc`. Compiler validation
does not prove in-game behavior; live S1x testing is still required. Other
installed scripts with compile errors can also prevent a match from loading.

## Other scripts (legacy installation notes)

combat training custom difficulty and campaign to

EMZ/EMP zombies Nerf  

atlas 45 upgrade similar to the cell 3 culterizer 

make a folder in s1 call it scripts now in the scripts folder create 3 new folders 1 says mp 1 says sv 1 says zm

for autobots.gsc put in the mp folder

for auto_bots_zombies.gsc and zm_emz.gsc and
s1_scripts_zm_atlas45_damage.gsc put them in zm folder

for custom names put Bots.txt next to where you made the scrips folder
