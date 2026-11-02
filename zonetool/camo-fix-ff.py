#!/usr/bin/env python3
"""Give every weapon in a ZoneTool S1 fastfile its first-person camo material override.

ZoneTool's weapon_def::write converts WeaponDef::camoWorldModelMaterialOverride to an asset reference but never
converts camoViewModelMaterialOverride, so a non-blank view override is written as a raw in-process Material*
pointer, which the engine decodes as an offset and crashes on.  patch-weapons.py therefore blanks the view
override in the weapon JSON, and a blank view override means the weapon has no first-person camo (the Mk2-Mk25
Pack-a-Punch camos never show).  Every stock gun names the same material in both overrides, so after the build this
tool copies the world override's asset reference into the view slot of every WeaponDef in the zone.

Layout of the S1 fastfile (zonetool/game/shared.hpp, s1/zone.cpp): XFileHeader (packed, 44 bytes, the last 16 are
baseFileLen and totalFileLen), imageCount XStreamFile entries (24 bytes each) between the first 28 header bytes and
the two lengths, then one zlib stream holding XZoneMemory<7> and the asset data.  The WeaponDef camo overrides are
the qwords at 0x38 (world) and 0x40 (view); the next qword is the szXAnimsRightHanded "data follows" pointer, which
ZoneTool writes as 0xFDFDFDFFFFFFFFFF, and the first qword of the WeaponDef (szInternalName) is the same marker.
A WeaponDef that needs the fix is therefore  <world ref 0xFDFDFDF3........> <0 x8> <data follows>  at 0x38 of a
struct that starts with <data follows> and is 0xDE8 bytes long, immediately followed by its own name string.  The
name has to be one of the weapons in --weapons-dir that has a world override, and every such weapon has to be found
exactly once, or the tool refuses to write anything.

usage: camo-fix-ff.py <in.ff> --weapons-dir dump/exo_patch/weapons [--out <out.ff>] [--dry-run]
  Without --out the fastfile is replaced; the original is kept as <in.ff>.nocamofix.
  Check the result with  run-zonetool.sh -verifyzone <name>  and by dumping it again: the dumped weapons then name
  the same material in camoViewModelMaterialOverride and camoWorldModelMaterialOverride.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import struct
import sys
import zlib
from pathlib import Path

HEADER_FIXED = 28
STREAM_FILE = 24
FOLLOW = b"\xff" * 5 + b"\xfd" * 3
WORLD_REF = re.compile(rb"(.{4}\xf3\xfd\xfd\xfd)\x00{8}\xff{5}\xfd{3}", re.S)
STRUCT_START = 0x38


WEAPON_DEF_SIZE = 0xDE8


def die(msg):
    sys.exit("camo-fix-ff: " + msg)


def expected_names(weapons_dir):
    names = set()
    for f in sorted(Path(weapons_dir).glob("*.json")):
        d = json.loads(f.read_text())
        if d.get("camoWorldModelMaterialOverride"):
            if d.get("camoViewModelMaterialOverride") not in ("", None):
                die(f"{f.name}: the view override is not blank, the build would carry a raw pointer")
            names.add(f.stem)
    return names


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ff")
    ap.add_argument("--weapons-dir", required=True)
    ap.add_argument("--out")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--level", type=int, default=9)
    args = ap.parse_args()

    ff = Path(args.ff).read_bytes()
    magic, version, comp, ctype, psize, lsize, _, _, nimg = struct.unpack_from("<8sIBBBBIII", ff, 0)
    if magic != b"S1ffu100" or comp != 1 or ctype != 1 or psize != 8:
        die(f"not a zlib S1 fastfile: {magic!r} compress={comp} type={ctype} pointer={psize}")
    lens_at = HEADER_FIXED + nimg * STREAM_FILE
    base, total = struct.unpack_from("<QQ", ff, lens_at)
    data_at = lens_at + 16
    if base != len(ff):
        die(f"baseFileLen {base} is not the file size {len(ff)}")
    extra = total - base

    d = zlib.decompressobj()
    raw = bytearray(d.decompress(ff[data_at:]))
    if not d.eof or d.unused_data:
        die("the zlib stream does not end at the end of the file")
    print(f"zone: {len(raw)} bytes, {nimg} stream files, header version {version}")

    expect = expected_names(args.weapons_dir)
    hits = {}
    for m in WORLD_REF.finditer(raw):
        pos = m.start()
        start = pos - STRUCT_START
        if start < 0 or raw[start:start + 8] != FOLLOW:
            continue
        name_at = start + WEAPON_DEF_SIZE
        name = bytes(raw[name_at:name_at + 80]).split(b"\x00")[0].decode("latin1")
        if name not in expect:
            continue
        if name in hits:
            die(f"{name}: two WeaponDefs match")
        hits[name] = pos
    print(f"WeaponDefs with a world camo reference and a blank view reference: {len(hits)} (expected {len(expect)})")
    if set(hits) != expect:
        die("missing: " + ", ".join(sorted(expect - set(hits))) + "; nothing written")
    refs = {n: bytes(raw[p:p + 8]) for n, p in hits.items()}
    lows = sorted(struct.unpack("<I", r[:4])[0] for r in refs.values())
    print("world refs (low dword, alias offset):", ", ".join(f"{v:#x}" for v in lows[:6]), "...")
    if args.dry_run:
        return

    for name, p in hits.items():
        raw[p + 8:p + 16] = refs[name]

    new = zlib.compress(bytes(raw), args.level)
    nbase = data_at + len(new)
    out = bytearray(ff[:lens_at])
    out += struct.pack("<QQ", nbase, nbase + extra)
    out += new
    check = zlib.decompress(bytes(out[data_at:]))
    if check != bytes(raw):
        die("recompressed stream does not round-trip")

    dest = Path(args.out) if args.out else Path(args.ff)
    if not args.out:
        shutil.copy2(args.ff, args.ff + ".nocamofix")
    tmp = dest.with_name(dest.name + ".tmp")
    tmp.write_bytes(out)
    os.replace(tmp, dest)
    print(f"wrote {dest}: {len(out)} bytes, sha256 {hashlib.sha256(out).hexdigest()}")


main()
