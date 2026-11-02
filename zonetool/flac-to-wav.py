#!/usr/bin/env python3
"""Decode the FLAC loaded sounds a ZoneTool pack uses into PCM WAV files, so the builder embeds PCM instead of FLAC.

ZoneTool embeds a loaded sound inline: as FLAC when only <name>.flac exists, as PCM when <name>.wav exists
(loaded_sound::parse looks for the .wav in every search path before it looks for the .flac).  In the game
(test 5) the wonder weapons had no reload sound.  Every reload notetrack alias of the Line Gun, Microwave and
Trident is FLAC, while the multiplayer weapons' reload aliases are PCM, so every FLAC the pack holds is decoded
to <out-dir>/loaded_sound/<name>.wav and that WAV wins at the next build.  That FLAC is the cause is a hypothesis
that the next test has to confirm.  The samples stay bit-exact (flac -d checks the stream's MD5); only the pack
grows, to about 2.5 times the size of those sounds.

The sounds are the loaded_sound assets the last build wrote into logs/verify_<pack>.log ("Loading asset ... of type
loaded_sound").  A recipe change can pull in sounds that log does not list yet: name them in EXTRA_SOUNDS (space
separated), or run the script again after the next build, which prints how many sounds it had to convert.

<out-dir> has to be one of the recipe's addpath lines (the one patch-weapons.py writes to), or the builder never sees
the WAVs.

usage (from the workspace root):  flac-to-wav.py zone_source/<pack>.csv dump/<out-dir> [build-log]
"""
import os
import re
import subprocess
import sys
import wave
from pathlib import Path

SOUND = re.compile(r'Loading asset "([^"]+)" of type loaded_sound')


def csv_addpaths(path):
    for raw in path.read_text(encoding="utf-8").splitlines():
        fields = [part.strip() for part in raw.strip().split(",")]
        if fields[0] == "addpath" and len(fields) > 1:
            yield Path(fields[1].replace("\\", "/"))


def first(search, relative):
    return next((p / relative for p in search if (p / relative).is_file()), None)


def decode(source, dest):
    dest.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["flac", "-d", "-s", "-f", "-o", str(dest), str(source)], check=True)
    with wave.open(str(dest)) as wav:
        if wav.getcomptype() != "NONE":
            sys.exit(f"{dest}: the decoded file is not PCM")


def main(argv):
    if len(argv) not in (3, 4):
        sys.exit(__doc__)
    csv_path, out_dir = Path(argv[1]), Path(argv[2])
    log = Path(argv[3]) if len(argv) == 4 else Path("logs") / f"verify_{csv_path.stem}.log"
    search = list(csv_addpaths(csv_path))
    if out_dir.resolve() not in [p.resolve() for p in search]:
        sys.exit(f"{out_dir} is not an addpath of {csv_path}")

    names = dict.fromkeys(SOUND.findall(log.read_text(encoding="utf-8", errors="replace")))
    names.update(dict.fromkeys(os.environ.get("EXTRA_SOUNDS", "").split()))

    pcm = converted = 0
    missing = []
    for name in names:
        if first(search, f"loaded_sound/{name}.wav"):
            pcm += 1
            continue
        source = first(search, f"loaded_sound/{name}.flac")
        if source is None:
            missing.append(name)
            continue
        decode(source, out_dir / "loaded_sound" / f"{name}.wav")
        converted += 1

    print(f"{len(names)} loaded sounds: {pcm} already PCM, {converted} converted from FLAC, "
          f"{len(missing)} without a source file (referenced only)")
    for name in missing:
        print(f"  no source: {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
