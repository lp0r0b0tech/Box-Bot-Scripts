combat training custom difficulty and campaign to

EMZ/EMP zombies Nerf  

atlas 45 upgrade similar to the cell 3 culterizer 

make a folder in s1 call it scripts now in the scripts folder create 3 new folders 1 says mp 1 says sv 1 says zm

for autobots.gsc put in the mp folder

for auto_bots_zombies.gsc and zm_emz.gsc and
s1_scripts_zm_atlas45_damage.gsc put them in zm folder

for custom names put Bots.txt next to where you made the scrips folder

## S1x multiplayer class slots

`s1x_unlock_classes.gsc` enables S1x's `cg_unlockall_classes` setting and
rechecks it once per second during a locally hosted MP match, in case a mod
resets it. It unlocks custom-class slots (including DLC class-slot locks),
not weapons, loot, rank, or prestige, and does not overwrite saved loadouts.

1. Back up your player profile/config before troubleshooting mods.
2. For the S1x loader linked below, place the file directly in
   `<game directory>/s1x/scripts/s1x_unlock_classes.gsc`, **not** a nested
   `mp` folder. This script's installation differs from the older instructions
   above; forks with different loaders may use different directories.
3. Start a local/private multiplayer match to execute the script. Then reopen
   the class menu; on older S1x builds, leave the match and open Create-a-Class
   in the frontend instead. Scripts do not execute in the frontend alone.
4. If you only need to unlock slots from the menu, enter
   `cg_unlockall_classes 1` in your **local client console** instead.

This is a client-menu unlock, not a permanent profile repair. It deliberately
does nothing on dedicated servers or in Exo Zombies/Survival; installing it on
a server does not unlock other players' client menus. S1x marks this setting
as saved, so removing the script may leave it enabled. To undo it, remove the
file, restart S1x, and enter `cg_unlockall_classes 0` in the client console.

If slots remain locked, temporarily disable conflicting mods and retry with
S1x's stock UI. A replaced class menu, missing S1x unlock hooks, corrupted
loadouts, or a mode that disallows class selection cannot be repaired by this
setting. Older builds may only apply the unlock in the frontend.

Implementation references:
[class-menu unlock hooks](https://github.com/CBServers/s1x-client/blob/ec96ff7ab84e61277ecf360bd0487cd6240a19d9/data/ui_scripts/stats/__init__.lua#L1-L17),
[saved unlock setting](https://github.com/CBServers/s1x-client/blob/ec96ff7ab84e61277ecf360bd0487cd6240a19d9/src/client/component/stats.cpp#L61-L85),
and [standalone GSC loader](https://github.com/Mirraculous/s1x-client/blob/092102312404734a63c63a061c429dededc08799/src/client/component/gsc/script_loading.cpp#L172-L218).

Manual check (requires S1x): with other mods disabled, set
`cg_unlockall_classes 0`, start a local MP match, and verify it becomes `1`.
Reopen Create-a-Class and check the previously locked custom slots. Reset the
setting to `0` during the match and verify it returns to `1` within a second.
Confirm existing loadouts/rank are unchanged and repeat after a map restart.
With the setting reset to `0`, also confirm it stays `0` in Zombies/Survival.
