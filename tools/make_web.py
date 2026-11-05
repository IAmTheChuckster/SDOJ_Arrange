#!/usr/bin/env python3
"""Generate index.html (browser patcher) and DoDonPachi SaiDaiOuJou Arrange.mra
from sdoj_patch_data.py. Needs your original ddpsdoj.zip only to compute
the patched u4 CRC (no ROM data is written anywhere).

Usage: python3 tools/make_web.py path/to/ddpsdoj.zip [build-number]
"""
import base64, json, os, re, subprocess, sys, zipfile, zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
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

    mra_path = os.path.join(ROOT, 'DoDonPachi SaiDaiOuJou Arrange.mra')
    mra = open(mra_path).read()
    mra = re.sub(r'(<part name="arr_u4" crc=")[0-9a-fA-F]{8}', lambda m: m.group(1) + '%08x' % pcrc, mra)
    open(mra_path, 'w').write(mra)

    # update the published page in place (no separate template)
    ip = os.path.join(ROOT, 'index.html')
    html = open(ip).read()
    old_crc = re.search(r'PATCHED_CRC = 0x([0-9a-f]{8})', html).group(1)
    def sub(pat, rep, h):
        h2, n = re.subn(pat, rep, h, count=1, flags=re.S)
        if n != 1:
            sys.exit('index.html: pattern not found: ' + pat)
        return h2
    html = sub(r'const ORIG_CRC = 0x[0-9a-f]+, PATCHED_CRC = 0x[0-9a-f]+',
               'const ORIG_CRC = 0x%08x, PATCHED_CRC = 0x%08x' % (ORIG_CRC, pcrc), html)
    html = sub(r'const PATCH = \[.*?\];\n', lambda m: 'const PATCH = ' + json.dumps(patch) + ';\n', html)
    html = sub(r'const MRA = ".*?";\n', lambda m: 'const MRA = ' + json.dumps(mra) + ';\n', html)
    html = html.replace('<td class="mono">%s</td>' % old_crc, '<td class="mono">%08x</td>' % pcrc)
    html = re.sub(r'build \d+', 'build ' + build, html)
    open(os.path.join(ROOT, 'index.html'), 'w').write(html)

    p = os.path.join(ROOT, 'sdoj_patch.py')
    s = open(p).read()
    s = re.sub(r'PATCHED_CRC = 0x[0-9A-Fa-f]{8}', 'PATCHED_CRC = 0x%08X' % pcrc, s)
    open(p, 'w').write(s)
    rp = os.path.join(ROOT, 'README.md')
    rd = open(rp).read()
    rd = re.sub(r'(the patched program ROM \(CRC `)[0-9a-f]{8}', lambda m: m.group(1) + '%08x' % pcrc, rd)
    open(rp, 'w').write(rd)
    print('patched u4 CRC %08x, build %s -> index.html, DoDonPachi SaiDaiOuJou Arrange.mra' % (pcrc, build))


if __name__ == '__main__':
    main()
