put scripts folder into s1 folder
put bots.txt in s1 folder 2

## Free Campaign weapon shop

Copy `scripts/sp/s1_scripts_sp_campaign_weapon_shop.gsc` into
`s1/scripts/sp/`. Enable the shop in the game console before starting or
restarting a Campaign map:

```text
set scr_sp_campaign_weapon_shop 1
```

Hold **Aim** and tap **Melee** to open the shop. Use **Attack**/**Melee** to
browse, **Use** to add the selected weapon for free, and **Frag** to close.
The shop is disabled by default.

The roster uses IDs referenced by this repository's Multiplayer GSC roster
and Exo Zombies zone manifests. Those manifests are not Campaign weapon
fastfiles: the shop only grants a weapon if the active Campaign assets can
load it. Missing IDs are reported in-game and in the console. A
Campaign-compatible fastfile/content port is still required for weapons that
are not already available in Campaign; this GSC does not convert or create
weapon assets.
