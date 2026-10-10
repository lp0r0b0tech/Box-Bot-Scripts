put scripts folder into s1 folder
put bots.txt in s1 folder 2

## Dump Exo Zombies map assets with ZoneTool

The pasteable commands are in `zonetool_exo_zombies_dump.txt`, split into
SHARED ZONES, ARK, LAB, H2O, and BRG sections. Copy only one section's command
line at a time into the x64 ZoneTool console, then wait for it to finish before
pasting the next section. The semicolons separate commands, and zones are
unloaded between fastfiles to avoid accumulating assets across the full map.

ZoneTool reads assets from your local game installation; this repository does
not include extracted game assets. Dumping assets does not rebuild or install
the map fastfiles. The `.zone` files in this repository still need to be built
separately with a compatible tool.

This does not make ZoneTool's limit infinite or guarantee no crash: if one
fastfile by itself exceeds the material limit, it may still fail. Stop if that
happens; the tool would need a source change and rebuild to address that case.
