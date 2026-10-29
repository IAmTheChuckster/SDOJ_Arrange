#!/usr/bin/env python3
"""SDOJ Resurrected patcher (Python 3, standard library only).

Usage:
    python3 sdoj_patch.py ddpsdoj.zip [output.zip]

Reads your own ddpsdoj (DoDonPachi SaiDaiOuJou) ROM set, patches the program
ROM u4 and writes a new zip (default: patched/ddpsdoj.zip). All other files are
copied unchanged. The original ROM is not modified.
"""
import os, sys, zipfile, zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdoj_patch_data import CHANGES, ORIG_BOOT_LITERAL

U4_SIZE = 4194560
U4_CRC = 0xE2A4411C  # original ddpsdoj u4


def swap16(b):
    b = bytearray(b)
    b[0::2], b[1::2] = b[1::2], b[0::2]
    return b


def patch_u4(u4):
    if len(u4) != U4_SIZE:
        sys.exit('u4 has the wrong size (%d), expected %d' % (len(u4), U4_SIZE))
    be = swap16(u4)
    lit = int.from_bytes(be[0x1D8:0x1DC], 'big')
    if lit != ORIG_BOOT_LITERAL:
        sys.exit('u4 is not an unpatched ddpsdoj program ROM (boot literal %08X)' % lit)
    for off, data in CHANGES:
        if off != 0x1D8 and any(x != 0xFF for x in be[off:off + len(data)]):
            sys.exit('u4 free space at %06X is not empty - unexpected dump' % off)
        be[off:off + len(data)] = data
    return bytes(swap16(be))


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    src = sys.argv[1]
    dst = sys.argv[2] if len(sys.argv) > 2 else os.path.join('patched', 'ddpsdoj.zip')
    with zipfile.ZipFile(src) as zin:
        names = zin.namelist()
        u4name = next((n for n in names if os.path.basename(n).lower() == 'u4'), None)
        if not u4name:
            sys.exit('no u4 in %s' % src)
        u4 = zin.read(u4name)
        crc = zlib.crc32(u4) & 0xFFFFFFFF
        if crc != U4_CRC:
            print('warning: u4 CRC %08X differs from the known dump %08X' % (crc, U4_CRC))
        new = patch_u4(u4)
        os.makedirs(os.path.dirname(os.path.abspath(dst)), exist_ok=True)
        with zipfile.ZipFile(dst, 'w', zipfile.ZIP_DEFLATED) as zout:
            for n in names:
                zout.writestr(n, new if n == u4name else zin.read(n))
    print('patched u4 CRC %08X' % (zlib.crc32(new) & 0xFFFFFFFF))
    print('wrote', dst)


if __name__ == '__main__':
    main()
