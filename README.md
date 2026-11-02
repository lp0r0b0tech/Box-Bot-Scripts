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

## Exo Zombies weapon shop: loading all its weapons

`scripts/zm/s1_scripts_zm_exo_zombies_dlc_weapon_shop.gsc` (the advanced version with the `mods/exo_weapons_*`
pack logic) can only sell a weapon the game has loaded, and a GSC cannot load fastfiles. The `zonetool/` folder
builds `exo_weapons_all.ff` (all 27 of its weapons) with [ZoneTool](https://github.com/Joelrau/x64-zt), to be
installed as `mods/exo_weapons_all/mod.ff` and selected by starting the game with
`+loadmod mods/exo_weapons_all` (in the CB Servers launcher: Game Settings, Advanced, Launch Options; a plain
`+set fs_game` does not mount it).
See [ZONETOOL-LOAD-SHOP-WEAPONS.md](ZONETOOL-LOAD-SHOP-WEAPONS.md). The built
`.ff` is made of the game's own assets and is not in this repository. Earlier builds loaded in the game with all 27
weapons registered. The first of them had visible defects (multiplayer weapons as red boxes, no wonder-weapon reload
sounds, a Line Gun without projectile or damage); the retest did not mention those, but reported optics that did not
work right, no alternate fire on the Ohm and the XMG, no Mk2 to Mk25 camos, zombies that ignored the player (a
leftover local test script) and too little ammunition on the multiplayer weapons. The next retest asked for four
things: bullet and zombie-death effects for the Microwave Gun, working Mk2 and Mk15 camos, melee on the multiplayer
weapons with and without the exo suit, and a Riot Shield that can be placed on every Zombies map. The current build
targets those four and has not been tried in the game yet. Four support scripts go with it,
`scripts/zm/exo_zombies_<weapon>_support.gsc` for the Line Gun, the Microwave Gun, the Riot Shield and the Trident
(the guide says which to copy).
