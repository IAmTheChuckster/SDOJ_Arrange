#!/usr/bin/env python3
"""SaiDaiOuJou 2.0 patcher (Python 3, standard library only).

Usage:
    python3 sdoj_patch.py ddpsdoj.zip [--zip] [--mra] [-o FILE]

Reads your own ddpsdoj (DoDonPachi SaiDaiOuJou) ROM set (or a loose u4 file) and
writes the patched program ROM sdoj2_u4 (or -o FILE).
  --zip   also write ddpsdoj20.zip: your set with u4 replaced by sdoj2_u4
  --mra   also write "SaiDaiOuJou 2.0.mra" (MiSTer), with the patched CRC
The original files are not modified.
"""
import os, re, sys, zipfile, zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdoj_patch_data import CHANGES, ORIG_BOOT_LITERAL

U4_SIZE = 4194560
U4_CRC = 0xE2A4411C  # original ddpsdoj u4
OUT_U4 = 'sdoj2_u4'
PATCHED_CRC = 0xBEE48395  # set by tools/make_web.py


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
    args = sys.argv[1:]
    if not args or args[0] in ('-h', '--help'):
        sys.exit(__doc__)
    want_zip = '--zip' in args
    want_mra = '--mra' in args
    out = None
    if '-o' in args:
        i = args.index('-o')
        if i + 1 >= len(args):
            sys.exit('-o needs a file name')
        out = args[i + 1]
        del args[i:i + 2]
    src = next((a for a in args if not a.startswith('-')), None)
    if not src:
        sys.exit(__doc__)
    names = None
    zin = None
    if zipfile.is_zipfile(src):
        zin = zipfile.ZipFile(src)
        names = zin.namelist()
        u4name = next((n for n in names if os.path.basename(n).lower() == 'u4'), None)
        if not u4name:
            sys.exit('no u4 in %s' % src)
        u4 = zin.read(u4name)
    else:
        u4 = open(src, 'rb').read()
    crc = zlib.crc32(u4) & 0xFFFFFFFF
    if crc != U4_CRC:
        print('warning: u4 CRC %08X differs from the known dump %08X' % (crc, U4_CRC))
    new = patch_u4(u4)
    nc = zlib.crc32(new) & 0xFFFFFFFF
    print('patched u4 CRC %08X%s' % (nc, '' if nc == PATCHED_CRC else ' (does not match release %08X!)' % PATCHED_CRC))
    out = out or OUT_U4
    open(out, 'wb').write(new)
    print('wrote', out)
    if want_zip:
        if zin is None:
            sys.exit('--zip needs the ddpsdoj.zip set as input, not a loose u4')
        with zipfile.ZipFile('ddpsdoj20.zip', 'w', zipfile.ZIP_DEFLATED) as zout:
            for n in names:
                if n == u4name:
                    zout.writestr(os.path.join(os.path.dirname(n), OUT_U4), new)
                else:
                    zout.writestr(n, zin.read(n))
        print('wrote ddpsdoj20.zip')
    if want_mra:
        mra = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'SaiDaiOuJou 2.0.mra')).read()
        mra = re.sub(r'(<part name="sdoj2_u4" crc=")[0-9a-fA-F]{8}', lambda m: m.group(1) + '%08x' % nc, mra)
        open('SaiDaiOuJou 2.0.mra', 'w').write(mra)
        print('wrote SaiDaiOuJou 2.0.mra')


if __name__ == '__main__':
    main()
