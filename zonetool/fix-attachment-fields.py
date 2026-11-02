#!/usr/bin/env python3
"""Restore the numbers ZoneTool loses in every weapon attachment it dumps and rebuilds.

A WeaponAttachment carries an array of 16-byte WAFields: a weapon-def field index, a type, an operation code and an
8-byte parameter.  ZoneTool (weaponattachment.cpp) treats the parameter of the integer types as a float:
    type 4 (WAFIELD_TYPE_INT)     dump: static_cast<int>(parm.p_float)         parse: parm.p_float = (float)value
    type 9 (WAFIELD_TYPE_FLOAT32) dump: static_cast<int>(parm.p_float * 1000)  parse: parm.p_float = value / 1000.0f
but the engine stores a real int there (a time in milliseconds, a damage, a shot count, ...).  A stock "SET" value of
12 is the int 0x0000000C, which read as a float is 1.7e-44, so the dump says 0 and the rebuilt attachment sets the
field to 0.  Every SET of a type 4 or type 9 field is lost that way, and the ADD fields of the float multipliers
(xmags: 1.5) are truncated.  The Ohm's alternate mode (attachment sensorheartbeatzm: shotCount, damage, fireTime, ...)
therefore did nothing, because its ZoneTool copy set all of them to 0.  The types 6 (bool) and 7 (float) survive.

This tool puts the stock numbers back after the build.  For every WeaponAttachment in the built zone it
  1. finds the attachment's WAField array in the built zone (ZoneTool writes the struct, then the name at +0x78;
     "data follows" pointers sit at 0x48/0x50 and numFields at 0x58; the array is the first run of fields after the
     struct that has the dump's (index, type, code) sequence),
  2. finds the stock struct of that name in the stock zone the build took the attachment from (the first directory of
     the recipe's addpath list that has dump/<dir>/attachments/<name>.json and a <game>/<dir>.ff).  A stock zone
     does not repeat the name after the struct: the name pointer is an offset into the zone's table of attachment
     names ("ncs_att_level" followed by the sorted names), counted in the memory block of the strings, so it differs
     from the position in the file by a constant per table.  The tool finds that constant by letting every
     struct vote for the table positions of the attachment names of the zone (dump/<dir>/attachments/*.json); the
     wanted array is then the first fitting run after the bound struct, and has to carry every value the dump
     keeps without loss (type 7 floats, type 6 bools, the truncated numbers of the types 4 and 9),
  3. copies the parameter of every non-pointer field (types 4, 6, 7, 9) from the stock array into the built one:
     4 bytes for the numbers, 1 byte for the bool (the rest of the 8 bytes is uninitialised in stock zones and zero
     in built ones).
The pointer types (0 string, 10 fx, 11 model, 12 anim, 13 material, 15 sound, 16 tracer) are asset references the
build writes itself and are never touched.

Stock zones (type 4, LZ4) are read with s1ff.py; the built zone is the zlib stream of a ZoneTool fastfile, rewritten
like camo-fix-ff.py does (level 9, baseFileLen/totalFileLen).  The tool refuses to write anything if a name cannot be
bound to exactly one stock struct, if a struct's numFields differs from its dump, or if an array does not agree with
the dump in the values that survive.  It is idempotent.  A second ZoneTool dump of the repaired fastfile still shows
the zeros (the dump bug is the same); check the result with --check, which reads the raw bytes.

usage: fix-attachment-fields.py <in.ff> --dump-dir dump --recipe zone_source/exo_weapons_all.csv --game-dir <game dir>
                                [--out <out.ff>] [--dry-run] [--check] [--only name,name]
  Without --out the fastfile is replaced; the original is kept as <in.ff>.noattfix.
  --check  report only; exit status 1 if any field of any attachment still differs from stock.
"""
import argparse
import collections
import hashlib
import json
import math
import os
import re
import shutil
import struct
import sys
import zlib
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import s1ff  # noqa: E402

HEADER_FIXED = 28
STREAM_FILE = 24
FOLLOW = b"\xff" * 5 + b"\xfd" * 3
OFFSET_MARK = b"\xf3\xfd\xfd\xfd"
NUMERIC = (4, 6, 7, 9)
MEANING = {4: 4, 6: 1, 7: 4, 9: 4}
STRUCT_SIZE = 0x78
SEARCH_WINDOW = 0x8000
STOCK_WINDOW = 1 << 26
NAME_TABLE_WINDOW = 0x1000000
INT_MIN = -2147483648


def die(msg):
    sys.exit("fix-attachment-fields: " + msg)


def addpath_dirs(recipe):
    dirs = []
    for line in Path(recipe).read_text().splitlines():
        m = re.match(r"\s*addpath,\s*(\S+)", line)
        if m:
            dirs.append(re.split(r"[\\/]", m.group(1))[-1])
    return dirs


def f32(x):
    return struct.unpack("<f", struct.pack("<f", x))[0]


def trunc_int(x):
    if math.isnan(x) or math.isinf(x) or abs(x) >= 2147483648.0:
        return INT_MIN
    return int(x)


def dumped_value(ftype, parm):
    """What ZoneTool's dump would print for these 8 parameter bytes (None for the pointer types)."""
    if ftype == 4:
        return trunc_int(struct.unpack_from("<f", parm)[0])
    if ftype == 9:
        return trunc_int(f32(struct.unpack_from("<f", parm)[0] * 1000.0))
    if ftype == 6:
        return bool(parm[0])
    if ftype == 7:
        return struct.unpack_from("<f", parm)[0]
    return None


def load_fields(path):
    j = json.loads(Path(path).read_text())
    return j["fields"] or []


def signature(fields):
    return [(f.get("index") if f["type"] != 12 else None, f["type"], f["code"]) for f in fields]


def rarity(entry):
    idx, ftype, code = entry
    score = {7: 3, 4: 2, 9: 1, 6: 1}.get(ftype, 0)
    if code != 3:
        score -= 1
    if idx:
        score -= 1
    return score


def shape_ok(buf, p, sig):
    """The (index, type, code) triples and the zero padding of every entry of the array at p."""
    for i, (idx, ftype, code) in enumerate(sig):
        q = p + 16 * i
        if buf[q + 1] != ftype or buf[q + 2] != code or buf[q + 3:q + 8] != b"\x00\x00\x00\x00\x00":
            return False
        if idx is not None and buf[q] != idx:
            return False
    return True


def values_ok(buf, p, fields):
    """Every value the dump keeps without loss, compared with the dump of the winning stock attachment."""
    for i, f in enumerate(fields):
        ftype = f["type"]
        if ftype not in NUMERIC:
            continue
        got = dumped_value(ftype, bytes(buf[p + 16 * i + 8:p + 16 * i + 16]))
        want = f["value"]
        if ftype == 7:
            if struct.pack("<f", want) != struct.pack("<f", got):
                return False
        elif ftype == 6:
            if bool(want) != got:
                return False
        elif got != want:
            return False
    return True


def find_arrays(buf, fields, start=0, end=None):
    """Offsets of every array in buf[start:end] with the dump's (index, type, code) sequence."""
    sig = signature(fields)
    usable = [i for i in range(len(sig)) if sig[i][0] is not None]
    if not usable:
        die("an attachment made only of anim fields cannot be located")
    k = min(usable, key=lambda i: (rarity(sig[i]), i))
    idx, ftype, code = sig[k]
    anchor = bytes([idx, ftype, code, 0, 0, 0, 0, 0])
    hits = []
    pos = start
    while True:
        h = buf.find(anchor, pos, end)
        if h < 0:
            break
        pos = h + 1
        p = h - 16 * k
        if p >= 0 and shape_ok(buf, p, sig):
            hits.append(p)
    return hits


def pack_attachments(raw):
    """name -> struct offset for every WeaponAttachment with fields that ZoneTool wrote into this zone."""
    found = {}
    double = FOLLOW + FOLLOW
    pos = 0
    while True:
        h = raw.find(double, pos)
        if h < 0:
            break
        pos = h + 1
        s0 = h - 0x48
        if s0 < 0 or raw[s0:s0 + 8] != FOLLOW:
            continue
        nf = struct.unpack_from("<i", raw, h + 16)[0]
        if not 1 <= nf <= 256:
            continue
        nm = bytes(raw[s0 + STRUCT_SIZE:s0 + STRUCT_SIZE + 64]).split(b"\x00")[0]
        if not re.fullmatch(rb"[a-z0-9_]{2,48}", nm):
            continue
        name = nm.decode()
        if name in found:
            die(f"{name}: two attachment structs in the built zone")
        found[name] = (s0, nf)
    return found


def offsets_before(buf, p, nf):
    """The u16 weapon-def offsets written right before a field array (0 to 7 bytes of alignment in between)."""
    return {bytes(buf[p - pad - 2 * nf:p - pad]) for pad in range(8)}


def meaningful(ftype, parm):
    return bytes(parm[:MEANING[ftype]])


def stock_structs(buf):
    """(struct offset, name offset pointer or None, numFields) of every WeaponAttachment with fields in a stock zone."""
    out = []
    double = FOLLOW + FOLLOW
    pos = 0
    while True:
        h = buf.find(double, pos)
        if h < 0:
            break
        pos = h + 1
        s0 = h - 0x48
        if s0 < 0:
            continue
        nf = struct.unpack_from("<i", buf, h + 16)[0]
        if not 1 <= nf <= 256:
            continue
        name_ptr, disp_ptr = bytes(buf[s0:s0 + 8]), bytes(buf[s0 + 8:s0 + 16])
        if not all(p == FOLLOW or p[4:] == OFFSET_MARK for p in (name_ptr, disp_ptr)):
            continue
        if any(not 0 <= x < 64 for x in struct.unpack_from("<4i", buf, s0 + 0x10)):
            continue
        out.append((s0, None if name_ptr == FOLLOW else struct.unpack_from("<I", name_ptr)[0], nf))
    return out


def bind_names(buf, structs, names):
    """name -> (struct offset, numFields): the names are looked up in the zone's name table by the structs' votes."""
    head = bytes(buf[:NAME_TABLE_WINDOW])
    where = {}
    for n in names:
        key = b"\x00" + n.encode() + b"\x00"
        at, ps = 0, []
        while True:
            i = head.find(key, at)
            if i < 0:
                break
            ps.append(i + 1)
            at = i + 1
        if ps:
            where[n] = ps
    bound = {}
    todo = []
    for s0, ptr, nf in structs:
        if ptr is None:
            nm = bytes(buf[s0 + STRUCT_SIZE:s0 + STRUCT_SIZE + 64]).split(b"\x00")[0].decode("latin1")
            if nm in bound:
                die(f"{nm}: two structs in the stock zone")
            bound[nm] = (s0, nf)
        else:
            todo.append((s0, ptr, nf))
    while todo:
        votes = collections.Counter(p - ptr for _, ptr, _ in todo for ps in where.values() for p in ps)
        if not votes:
            break
        delta, count = votes.most_common(1)[0]
        if count < 2:
            break
        rest = []
        for s0, ptr, nf in todo:
            hit = [n for n, ps in where.items() if ptr + delta in ps]
            if len(hit) == 1:
                if hit[0] in bound:
                    die(f"{hit[0]}: two structs in the stock zone")
                bound[hit[0]] = (s0, nf)
            else:
                rest.append((s0, ptr, nf))
        if len(rest) == len(todo):
            break
        todo = rest
    return bound


def read_ff(path):
    ff = Path(path).read_bytes()
    magic, version, comp, ctype, psize, lsize, _, _, nimg = struct.unpack_from("<8sIBBBBIII", ff, 0)
    if magic != b"S1ffu100" or comp != 1 or ctype != 1 or psize != 8:
        die(f"{path} is not a zlib S1 fastfile: {magic!r} compress={comp} type={ctype} pointer={psize}")
    lens_at = HEADER_FIXED + nimg * STREAM_FILE
    base, total = struct.unpack_from("<QQ", ff, lens_at)
    data_at = lens_at + 16
    if base != len(ff):
        die(f"baseFileLen {base} is not the file size {len(ff)}")
    d = zlib.decompressobj()
    raw = bytearray(d.decompress(ff[data_at:]))
    if not d.eof or d.unused_data:
        die("the zlib stream does not end at the end of the file")
    return ff, raw, lens_at, data_at, total - base


def write_ff(ff, raw, lens_at, data_at, extra, dest, level):
    new = zlib.compress(bytes(raw), level)
    nbase = data_at + len(new)
    out = bytearray(ff[:lens_at])
    out += struct.pack("<QQ", nbase, nbase + extra)
    out += new
    if zlib.decompress(bytes(out[data_at:])) != bytes(raw):
        die("recompressed stream does not round-trip")
    tmp = dest.with_name(dest.name + ".tmp")
    tmp.write_bytes(out)
    os.replace(tmp, dest)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ff")
    ap.add_argument("--dump-dir", required=True)
    ap.add_argument("--recipe", required=True)
    ap.add_argument("--game-dir", required=True)
    ap.add_argument("--out")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--only", default="")
    ap.add_argument("--level", type=int, default=9)
    args = ap.parse_args()

    dump = Path(args.dump_dir)
    game = Path(args.game_dir)
    dirs = [d for d in addpath_dirs(args.recipe) if (game / f"{d}.ff").exists()]
    if not dirs:
        die("no stock zone of the recipe's addpath list found in the game directory")

    ff, raw, lens_at, data_at, extra = read_ff(args.ff)
    print(f"built zone: {len(raw)} bytes")
    structs = pack_attachments(raw)
    only = {n for n in args.only.split(",") if n}
    plan = {}
    for name, (s0, nf) in sorted(structs.items()):
        if only and name not in only:
            continue
        src = next((d for d in dirs if (dump / d / "attachments" / f"{name}.json").exists()), None)
        if src is None:
            print(f"  {name}: no stock dump among the addpath directories, left alone")
            continue
        fields = load_fields(dump / src / "attachments" / f"{name}.json")
        if len(fields) != nf:
            die(f"{name}: the built struct has {nf} fields, the dump of {src} has {len(fields)}")
        sig = signature(fields)
        mine = [p for p in find_arrays(raw, fields, s0 + STRUCT_SIZE, s0 + STRUCT_SIZE + SEARCH_WINDOW)]
        if not mine:
            die(f"{name}: the field array is not within {SEARCH_WINDOW:#x} bytes after the struct")
        plan[name] = {"src": src, "fields": fields, "mine": mine[0], "sig": sig, "nf": nf}
        for i, f in enumerate(fields):
            if f["type"] in (6, 7):
                got = dumped_value(f["type"], bytes(raw[mine[0] + 16 * i + 8:mine[0] + 16 * i + 16]))
                want = f["value"]
                same = (struct.pack("<f", want) == struct.pack("<f", got)) if f["type"] == 7 else bool(want) == got
                if not same:
                    die(f"{name}: built field {i} ({f.get('name')}) is {got!r}, the dump of {src} says {want!r}")
    print(f"attachments with fields in the built zone: {len(structs)}; to look up in stock: {len(plan)}")

    by_zone = {}
    for name, p in plan.items():
        by_zone.setdefault(p["src"], []).append(name)
    stock_parms = {}
    for zone in sorted(by_zone):
        print(f"reading {zone}.ff ...", flush=True)
        buf = s1ff.read_zone(game / f"{zone}.ff")
        structs_here = stock_structs(buf)
        starts = sorted(s for s, _, _ in structs_here)
        zone_names = sorted(f.stem for f in (dump / zone / "attachments").glob("*.json"))
        bound = bind_names(buf, structs_here, zone_names)
        print(f"  {len(structs_here)} attachment structs with fields, {len(bound)} of them bound to a name")
        for name in by_zone[zone]:
            p = plan[name]
            if name not in bound:
                die(f"{name}: no attachment struct of {zone}.ff binds to the name")
            s0, nf = bound[name]
            if nf != p["nf"]:
                die(f"{name}: the stock struct in {zone}.ff has {nf} fields, the dump has {p['nf']}")
            # a model the attachment names for the first time is stored inline: the array can be far behind the struct,
            # but always before the data of the next attachment
            after = next((x for x in starts if x > s0), len(buf))
            arrays = find_arrays(buf, p["fields"], s0 + STRUCT_SIZE, min(after, s0 + STRUCT_SIZE + STOCK_WINDOW))
            if len(arrays) != 1:
                die(f"{name}: {len(arrays)} field arrays with the dump's fields follow the stock struct at {s0}")
            c = arrays[0]
            if not values_ok(buf, c, p["fields"]):
                die(f"{name}: the stock array at {c} does not carry the dump's values")
            if not offsets_before(buf, c, nf) & offsets_before(raw, p["mine"], nf):
                die(f"{name}: the weapon-def offsets before the stock array at {c} differ from the built zone's")
            stock_parms[name] = [meaningful(f["type"], buf[c + 16 * i + 8:c + 16 * i + 16]) if f["type"] in NUMERIC
                                 else None for i, f in enumerate(p["fields"])]
            print(f"  {name}: stock struct at {s0}, array at {c}")
        del buf

    changed = {}
    for name, p in plan.items():
        diffs = []
        for i, f in enumerate(p["fields"]):
            if f["type"] not in NUMERIC:
                continue
            at = p["mine"] + 16 * i + 8
            have = meaningful(f["type"], raw[at:at + 8])
            if have != stock_parms[name][i]:
                diffs.append((i, f.get("name", f.get("offset")), f["type"], f["code"], have.hex(),
                              stock_parms[name][i].hex()))
        if diffs:
            changed[name] = diffs
    total = sum(len(d) for d in changed.values())
    print(f"attachments that differ from stock: {len(changed)}, fields: {total}")
    for name, diffs in sorted(changed.items()):
        shown = [f"{d[1]}[{d[0]}] {d[4]}->{d[5]}" for d in diffs if d[2] in (4, 9)]
        print(f"  {name}: {len(diffs)} field(s)" + (("; " + "; ".join(shown[:6]) + (" ..." if len(shown) > 6 else "")) if shown else ""))
    if args.check:
        sys.exit(1 if changed else 0)
    if args.dry_run:
        return
    if not changed:
        print("nothing to repair")
        return

    for name, diffs in changed.items():
        for d in diffs:
            at = plan[name]["mine"] + 16 * d[0] + 8
            new = stock_parms[name][d[0]]
            raw[at:at + len(new)] = new
    dest = Path(args.out) if args.out else Path(args.ff)
    if not args.out:
        shutil.copy2(args.ff, args.ff + ".noattfix")
    out = write_ff(ff, raw, lens_at, data_at, extra, dest, args.level)
    print(f"wrote {dest}: {len(out)} bytes, sha256 {hashlib.sha256(out).hexdigest()}")


main()
