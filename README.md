put scripts folder into s1 folder
put bots.txt in s1 folder 2

## Dump Exo Zombies map assets with ZoneTool

The paste-ready command list is in `zonetool_exo_zombies_dump.txt`. Copy the four
lines into the x64 ZoneTool console after it is running from your Advanced
Warfare installation. `dumpmap <map>` dumps the map's required assets, so you
do not need to enter weapon asset names one by one.

ZoneTool reads assets from your local game installation; this repository does
not include extracted game assets. Dumping assets does not rebuild or install
the map fastfiles. The `.zone` files in this repository still need to be built
separately with a compatible tool.
