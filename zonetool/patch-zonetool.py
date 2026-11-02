#!/usr/bin/env python3
"""Binary patch for ZoneTool (Joelrau/x64-zt, S1 build `latest-2-g3802db4`): FX decal crash while building zones.

Bug: fxeffectdef.cpp write_fx_elem_def_visuals() writes THREE materials for every FX decal mark element
(`materials[0]`, `[1]` and `[2]`) but `FxElemMarkVisuals` only has TWO (`Material* materials[2]; // mc, wc`).
For every element but the last, `materials[2]` aliases the next element's `materials[0]` (harmless: that slot
is rewritten by the next iteration). For the LAST element it is the 8 bytes after the array, which hold
unrelated data (typically the ASCII text of the next material name), and are dereferenced as a `Material*`:

    access violation, RCX=0x6361706d692f636d ("mc/impac"), `mov rbx,[rcx]` in zonetool.exe

Fix: always write a null `materials[2]` (the correct behaviour). The `je` that skips the block on a null
pointer becomes an unconditional `jmp` to the same target.

Usage:  patch-zonetool.py [path/to/zonetool.exe]     (default: $WS/zonetool.exe, else ~/zonetool-workspace)
Idempotent. The first run keeps the pristine binary next to it as zonetool.exe.orig.
Tested against release `latest-2-g3802db4`; any other build is only patched if the exact code pattern is found once.

Not patchable (tried, do not retry): enlarging the engine's IMAGE / MATERIAL pools (13792 / 11648 entries) to load
more zones at once. init_zonetool() can double pools via reallocate_asset_pool(), but the engine finds an image's
slot with (ptr - &static_array) / 0x68 and keeps per-image tables in static arrays sized for the stock limit, so
a relocated IMAGE pool crashes the first zone swap (access violation at 0x140279a5e). Keep the set of zones loaded
in one process small enough for the stock limits instead (see the guide).
"""
import os
import re
import shutil
import sys

# mov rcx,[rax+rbx+0x10]; test rcx,rcx; je/jmp <skip>; mov rax,[rbp-0x31]; mov rax,[rax]; mov rdi,[rax+8]; mov rbx,[rcx]
PATTERN = re.compile(
    rb"\x48\x8b\x4c\x18\x10\x48\x85\xc9(?P<op>[\x74\xeb])(?P<rel>.)"
    rb"\x48\x8b\x45\xcf\x48\x8b\x00\x48\x8b\x78\x08\x48\x8b\x19",
    re.S,
)
MOV_RAX_RSI = b"\x48\x8b\xc6"  # the skip target stores `rsi` (always 0) as the pointer


def main():
    default = os.path.join(os.environ.get("WS", os.path.expanduser("~/zonetool-workspace")), "zonetool.exe")
    path = sys.argv[1] if len(sys.argv) > 1 else default
    data = bytearray(open(path, "rb").read())

    hits = list(PATTERN.finditer(bytes(data)))
    if len(hits) != 1:
        sys.exit(f"patch-zonetool: expected exactly 1 match for the decal materials[2] block, found {len(hits)} - "
                 "this zonetool build differs; not patching")
    m = hits[0]
    op_at = m.start("op")
    rel = m.group("rel")[0]
    rel = rel - 256 if rel >= 128 else rel
    target = op_at + 2 + rel
    if bytes(data[target:target + 3]) != MOV_RAX_RSI:
        sys.exit("patch-zonetool: jump target is not `mov rax,rsi`; not patching")

    if m.group("op") == b"\xeb":
        print(f"patch-zonetool: {path} is already patched")
        return

    backup = path + ".orig"
    if not os.path.exists(backup):
        shutil.copy2(path, backup)
    data[op_at] = 0xEB
    open(path, "wb").write(data)
    print(f"patch-zonetool: patched file offset {op_at:#x} (je -> jmp) in {path}; original kept as {backup}")


if __name__ == "__main__":
    main()
