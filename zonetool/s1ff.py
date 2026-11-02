#!/usr/bin/env python3
"""Read the raw zone image of an S1 (Advanced Warfare) fastfile.

Two flavours exist:
  * stock zones: header "S1ff0100", compress type 4 (LZ4).  The first 0x8000 bytes after the XFileHeader are the
    signature section (magic "S1ffs100"); the rest is LZ4 blocks:
      first block   : int32 uncompressedSize, 6 zero bytes, u8 1, u8 4, u32 compressedSize, u32 blockSize
      other blocks  : u32 compressedSize, u32 blockSize
      every block's data is padded to 4 bytes.
    Block data is NOT contiguous: counting from the first block header, a 0x4000-byte signature block (random looking,
    not part of any LZ4 block) is stored after every 0x800000 bytes of block stream, even in the middle of an LZ4
    block.  Zones smaller than 8 MiB have none.  Verified by decoding the whole of mp_zombie_ark.ff.
  * ZoneTool-built zones: header "S1ffu100", compress type 1 (zlib), one zlib stream, no signature section.
Both start with an XFileHeader whose layout is  header[8] version u32 compress u8 type u8 pointer u8 long u8
fileTime u64 imageCount u32 then imageCount * 24 bytes of XStreamFile, then baseFileLen u64 / totalFileLen u64.

usage as a module:  from s1ff import read_zone;  raw = read_zone(path)        (bytearray, the whole zone image)
                    from s1ff import iter_blocks; for blk in iter_blocks(path): ...   (64 KiB pieces, constant memory)
usage as a script:  s1ff.py <zone.ff> [out.bin]                                  (prints the layout, optionally writes the image)
"""
import ctypes
import mmap
import struct
import sys
import zlib

HEADER_FIXED = 28
STREAM_FILE = 24
SIGNATURE_SECTION = 0x8000
SEGMENT = 0x800000
SEGMENT_SIGNATURE = 0x4000

_lz4 = None


def _lz4_lib():
    global _lz4
    if _lz4 is None:
        _lz4 = ctypes.CDLL("liblz4.so.1")
        _lz4.LZ4_decompress_safe.argtypes = [ctypes.c_char_p, ctypes.c_void_p, ctypes.c_int, ctypes.c_int]
        _lz4.LZ4_decompress_safe.restype = ctypes.c_int
    return _lz4


def parse_header(ff):
    magic, version, comp, ctype, psize, lsize, _, _, nimg = struct.unpack_from("<8sIBBBBIII", ff, 0)
    lens_at = HEADER_FIXED + nimg * STREAM_FILE
    base, total = struct.unpack_from("<QQ", ff, lens_at)
    return {"magic": magic, "version": version, "compress": comp, "ctype": ctype, "pointer": psize,
            "images": nimg, "base": base, "total": total, "data_at": lens_at + 16}


class _BlockStream:
    """The block stream of a stock zone with the periodic 0x4000-byte signature blocks skipped."""

    def __init__(self, buf, start):
        self.buf = buf
        self.start = start
        self.pos = 0
        self.k = 1

    def _boundary(self):
        return self.k * SEGMENT + (self.k - 1) * SEGMENT_SIGNATURE

    def read(self, n):
        parts = []
        while n > 0:
            q = self._boundary()
            if self.pos >= q:
                self.pos = q + SEGMENT_SIGNATURE
                self.k += 1
                continue
            take = min(n, q - self.pos)
            at = self.start + self.pos
            chunk = bytes(self.buf[at:at + take])
            if len(chunk) != take:
                raise ValueError("truncated zone")
            parts.append(chunk)
            self.pos += take
            n -= take
        return b"".join(parts)


def _lz4_pieces(buf, h):
    """Yield the decompressed pieces (normally 64 KiB each) of a stock LZ4 zone held in `buf`."""
    lib = _lz4_lib()
    pos = h["data_at"]
    if bytes(buf[pos:pos + 8]) == b"S1ffs100":
        pos += SIGNATURE_SECTION
    st = _BlockStream(buf, pos)
    usize, _, u2, ct, csize, bsize = struct.unpack("<i6sBBII", st.read(20))
    if u2 != 1 or ct != 4:
        raise ValueError("unexpected first block header")
    expect = usize & 0xFFFFFFFF
    done = 0
    first = True
    while done < expect:
        if not first:
            csize, bsize = struct.unpack("<II", st.read(8))
        first = False
        if csize == 0 and bsize == 0:
            break
        src = st.read(csize)
        st.read((-csize) & 3)
        out = ctypes.create_string_buffer(bsize)
        n = lib.LZ4_decompress_safe(src, out, csize, bsize)
        if n == bsize:
            yield out.raw
        elif csize == bsize:
            yield src
        else:
            raise ValueError(f"LZ4 block failed ({n}) after {done} bytes")
        done += bsize
    if done != expect:
        raise ValueError(f"decompressed {done} bytes, header says {expect}")


def iter_blocks(path):
    """Yield the decompressed pieces of a zone in order without holding the whole image in memory."""
    with open(path, "rb") as f, mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ) as mm:
        h = parse_header(mm)
        if h["base"] != len(mm):
            raise ValueError(f"{path}: baseFileLen {h['base']} != file size {len(mm)}")
        if h["ctype"] == 4:
            yield from _lz4_pieces(mm, h)
        elif h["ctype"] == 1:
            d = zlib.decompressobj()
            pos = h["data_at"]
            while pos < len(mm) and not d.eof:
                piece = d.decompress(bytes(mm[pos:pos + (1 << 20)]))
                pos += 1 << 20
                if piece:
                    yield piece
            if not d.eof:
                raise ValueError("zlib stream is incomplete")
        else:
            raise ValueError(f"unsupported compression type {h['ctype']}")


def read_zone(path):
    raw = bytearray()
    for piece in iter_blocks(path):
        raw += piece
    return raw


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    raw = read_zone(sys.argv[1])
    with open(sys.argv[1], "rb") as f:
        print(parse_header(f.read(1 << 20)))
    print("zone image:", len(raw), "bytes")
    if len(sys.argv) > 2:
        with open(sys.argv[2], "wb") as f:
            f.write(raw)
