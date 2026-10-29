#!/usr/bin/env python3
"""Generate patcher/index.html (browser patcher) and patcher/SDOJ_Resurrected.mra
from patcher/sdoj_patch_data.py. Needs your original ddpsdoj.zip only to compute
the patched u4 CRC (no ROM data is written anywhere).

Usage: python3 tools/make_web.py path/to/ddpsdoj.zip [build-number]
"""
import base64, json, os, re, subprocess, sys, zipfile, zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'patcher'))
from sdoj_patch_data import CHANGES  # noqa: E402
import sdoj_patch  # noqa: E402

ORIG_CRC = 0xE2A4411C


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    u4 = zipfile.ZipFile(sys.argv[1]).read('u4')
    if zlib.crc32(u4) & 0xFFFFFFFF != ORIG_CRC:
        sys.exit('not the original ddpsdoj u4')
    patched = sdoj_patch.patch_u4(u4)
    pcrc = zlib.crc32(patched) & 0xFFFFFFFF
    build = sys.argv[2] if len(sys.argv) > 2 else subprocess.check_output(
        ['git', '-C', ROOT, 'rev-list', '--count', 'HEAD']).decode().strip()

    # file-coordinate (word-swapped) patches: same offsets, byte pairs swapped
    patch = []
    for off, data in CHANGES:
        assert off % 2 == 0 and len(data) % 2 == 0
        sw = bytearray(data)
        sw[0::2], sw[1::2] = data[1::2], data[0::2]
        patch.append([off, base64.b64encode(bytes(sw)).decode()])
    test = bytearray(u4)
    for off, b64 in patch:
        d = base64.b64decode(b64)
        test[off:off + len(d)] = d
    assert bytes(test) == patched, 'web patch table does not reproduce the Python patcher'

    mra_path = os.path.join(ROOT, 'patcher', 'SDOJ_Resurrected.mra')
    mra = open(mra_path).read()
    mra = re.sub(r'(<part name="u4" crc=")[0-9a-fA-F]{8}', lambda m: m.group(1) + '%08x' % pcrc, mra)
    open(mra_path, 'w').write(mra)

    html = open(os.path.join(ROOT, 'patcher', 'web_template.html')).read()
    html = (html.replace('__ORIG_CRC__', '0x%08x' % ORIG_CRC)
                .replace('__PATCHED_CRC__', '0x%08x' % pcrc)
                .replace('__PATCHED_HEX__', '%08x' % pcrc)
                .replace('__BUILD__', build)
                .replace('__PATCH__', json.dumps(patch))
                .replace('__MRA__', json.dumps(mra)))
    open(os.path.join(ROOT, 'patcher', 'index.html'), 'w').write(html)

    p = os.path.join(ROOT, 'patcher', 'sdoj_patch.py')
    s = open(p).read()
    s = re.sub(r'PATCHED_CRC = 0x[0-9A-Fa-f]{8}', 'PATCHED_CRC = 0x%08X' % pcrc, s)
    open(p, 'w').write(s)
    print('patched u4 CRC %08x, build %s -> patcher/index.html, patcher/SDOJ_Resurrected.mra' % (pcrc, build))


if __name__ == '__main__':
    main()
