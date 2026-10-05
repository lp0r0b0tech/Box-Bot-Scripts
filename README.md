put scripts folder into s1 folder
put bots.txt in s1 folder 2

Exo Zombies no bleedout: `scripts/zm/no_zombie_bleedout.gsc`
- Install as `s1/scripts/zm/no_zombie_bleedout.gsc` and start a new Exo Zombies match.
- Prevents normal zombies, hosts and dogs from automatically dying after roughly four minutes, including the last zombie in a round.
- Normal kills still work. Native stuck-AI cleanup remains enabled, so a zombie that cannot move or engage a player can still be removed after roughly a minute.
- Look for `[NZB] Zombie lifetime expiry disabled` in the console to confirm it loaded. Remove the file and restart the match to restore default behavior.
