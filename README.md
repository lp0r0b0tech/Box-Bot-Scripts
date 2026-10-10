put scripts folder into s1 folder
put bots.txt in s1 folder 2

## Dump Exo Zombies map assets with ZoneTool

The command list is in `zonetool_exo_zombies_dump.txt`. Enter its commands in
the x64 ZoneTool console one at a time, waiting for each command to finish.
It dumps only weapon assets from one fastfile at a time, unloading zones
between dumps. This is intended to avoid accumulating assets across the full
map dump.

ZoneTool reads assets from your local game installation; this repository does
not include extracted game assets. Dumping assets does not rebuild or install
the map fastfiles. The `.zone` files in this repository still need to be built
separately with a compatible tool.

If any single `dumpzone` command still exceeds the material limit, stop there:
that fastfile alone is too large for this approach, and changing the limit
requires modifying and rebuilding ZoneTool.
