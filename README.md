put scripts folder into s1 folder
put bots.txt in s1 folder 2

## Dump Exo Zombies map assets with ZoneTool

The single-line command is in `zonetool_exo_zombies_dump.txt`. Copy and paste
that whole line into the x64 ZoneTool console once. The semicolons separate
commands; each fastfile is dumped for weapon assets with zones unloaded between
dumps. This is intended to avoid accumulating assets across a full map dump.

ZoneTool reads assets from your local game installation; this repository does
not include extracted game assets. Dumping assets does not rebuild or install
the map fastfiles. The `.zone` files in this repository still need to be built
separately with a compatible tool.

This does not make ZoneTool's limit infinite or guarantee no crash: if one
fastfile by itself exceeds the material limit, it may still fail. Stop if that
happens; the tool would need a source change and rebuild to address that case.
