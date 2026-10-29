#!/usr/bin/env python3
"""Developer build: assemble src/patch.s, generate the boot loader, and write
patcher/sdoj_patch_data.py (changed u4 bytes only - no original ROM data).

Needs SH binutils (sh4-linux-gnu-as/ld/objcopy/nm, or sh-elf-*).
Usage: python3 tools/build.py
"""
import os, re, shutil, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'src')
OUT = os.path.join(ROOT, 'patcher', 'sdoj_patch_data.py')

RAM_BASE = 0x0CE00000          # free work RAM used for the patch code + variables
ROM_LOADER = 0x3E0000          # free space in u4 (byte offset, big-endian view)
ROM_BLOB = 0x3E1000
BOOT_LITERAL = 0x1D8           # boot ROM literal holding the main entry 0x0C1E40D0
MAIN_ENTRY = 0x0C1E40D0

# literal pointers in the unpacked program (RAM) redirected to our hooks
HOOKS = {
    'title_hook':   [0x0C221344, 0x0C2222D4, 0x0C222C88],
    'ds_hook':      [0x0C2212AC, 0x0C221308],
    'dn_hook':      [0x0C2212B4],
    'trybomb_hook': [0x0C211C0C],
    'acthyp_hook':  [0x0C21291C],
    'gp_hook':      [0x0C1F6E70, 0x0C27AFFC, 0x0C27C730, 0x0C27D1B8],
    'kill_hook':    [0x0C1F6C04, 0x0C20B3E4, 0x0C20B434, 0x0C21AC0C, 0x0C22AAAC],
    'bee_hook':     [0x0C22A030],
    'shot_stub0':  [0x0C2173B4],
    'shot_stub1':  [0x0C217670],
    'shot_stub2':  [0x0C217A34],
    'shot_stub3':  [0x0C217DC0],
    'shot_stub4':  [0x0C218144],
    'shot_stub5':  [0x0C2183B0],
    'shot_stub6':  [0x0C218724],
    'shot_stub7':  [0x0C2189E0],
    'shot_stub8':  [0x0C218D64],
    'shot_stub9':  [0x0C218FD0],
    'shot_stub10':  [0x0C219394],
    'shot_stub11':  [0x0C2196A0],
}
# original values, checked by the loader before patching (protects against other dumps)
ORIG = {
    0x0C221344: 0x0C221070, 0x0C2222D4: 0x0C221070, 0x0C222C88: 0x0C221070,
    0x0C2212AC: 0x0C1DD4DC, 0x0C221308: 0x0C1DD4DC, 0x0C2212B4: 0x0C1DD990,
    0x0C211C0C: 0x0C212600, 0x0C21291C: 0x0C1FA0D0,
    0x0C1F6E70: 0x0C1F8D40, 0x0C27AFFC: 0x0C1F8D40, 0x0C27C730: 0x0C1F8D40, 0x0C27D1B8: 0x0C1F8D40,
    0x0C1F6C04: 0x0C1FA320, 0x0C20B3E4: 0x0C1FA320, 0x0C20B434: 0x0C1FA320,
    0x0C21AC0C: 0x0C1FA320, 0x0C22AAAC: 0x0C1FA320,
    0x0C22A030: 0x0C22A8F0,
    0x0C2173B4: 0x0C2173D0,
    0x0C217670: 0x0C217680,
    0x0C217A34: 0x0C217A80,
    0x0C217DC0: 0x0C217DD0,
    0x0C218144: 0x0C218160,
    0x0C2183B0: 0x0C2183C0,
    0x0C218724: 0x0C218770,
    0x0C2189E0: 0x0C2189F0,
    0x0C218D64: 0x0C218D80,
    0x0C218FD0: 0x0C218FE0,
    0x0C219394: 0x0C2193E0,
    0x0C2196A0: 0x0C2196B0,
}


def tool(name):
    for pre in ('sh4-linux-gnu-', 'sh-elf-', 'sh-linux-gnu-'):
        p = shutil.which(pre + name)
        if p:
            return p
    sys.exit('missing SH binutils (%s)' % name)


def run(*a):
    subprocess.check_call(list(a))


def asm_link(src, base, tmp, name):
    o = os.path.join(tmp, name + '.o')
    elf = os.path.join(tmp, name + '.elf')
    binf = os.path.join(tmp, name + '.bin')
    run(tool('as'), '-big', '-o', o, src)
    run(tool('ld'), '-EB', '-Ttext=0x%08X' % base, '-e', '0x%08X' % base, '-o', elf, o)
    run(tool('objcopy'), '-O', 'binary', '-j', '.text', elf, binf)
    syms = {}
    for line in subprocess.check_output([tool('nm'), elf]).decode().splitlines():
        v, t, n = line.split()
        syms[n] = int(v, 16)
    return open(binf, 'rb').read(), syms


def loader_source(blob_len, table):
    words = (blob_len + 3) // 4
    lines = [
        '        .section .text',
        '! boot loader in u4 free space: copy patch code to RAM, redirect literals, jump to main',
        'start:',
        '        mov.l   l_src,r1',
        '        mov.l   l_dst,r2',
        '        mov.l   l_cnt,r3',
        'cp:     mov.l   @r1+,r0',
        '        mov.l   r0,@r2',
        '        dt      r3',
        '        bf/s    cp',
        '        add     #4,r2',
        '        mova    table,r0',
        '        mov     r0,r1',
        'tl:     mov.l   @r1+,r2          ! address (0 = end)',
        '        tst     r2,r2',
        '        bt      done',
        '        mov.l   @r1+,r3          ! expected original',
        '        mov.l   @r1+,r4          ! new value',
        '        mov.l   @r2,r5',
        '        cmp/eq  r3,r5',
        '        bf      tl               ! unexpected program: leave it alone',
        '        bra     tl',
        '        mov.l   r4,@r2',
        'done:   mov.l   l_main,r0',
        '        jmp     @r0',
        '        nop',
        '        .align 2',
        'l_src:  .long 0x%08X' % (0xA0000000 | ROM_BLOB),
        'l_dst:  .long 0x%08X' % RAM_BASE,
        'l_cnt:  .long %d' % words,
        'l_main: .long 0x%08X' % MAIN_ENTRY,
        'table:',
    ]
    for addr, orig, new in table:
        lines.append('        .long 0x%08X, 0x%08X, 0x%08X' % (addr, orig, new))
    lines.append('        .long 0')
    return '\n'.join(lines) + '\n'


def main():
    tmp = tempfile.mkdtemp()
    blob, syms = asm_link(os.path.join(SRC, 'patch.s'), RAM_BASE, tmp, 'patch')
    if len(blob) > 0xF000:
        sys.exit('patch too large')
    table = []
    for sym, addrs in HOOKS.items():
        for a in addrs:
            table.append((a, ORIG[a], syms[sym]))
    lsrc = os.path.join(tmp, 'loader.s')
    open(lsrc, 'w').write(loader_source(len(blob), table))
    loader, _ = asm_link(lsrc, 0xA0000000 | ROM_LOADER, tmp, 'loader')

    # changes in big-endian u4 coordinates
    changes = [
        (BOOT_LITERAL, (0xA0000000 | ROM_LOADER).to_bytes(4, 'big')),
        (ROM_LOADER, loader),
        (ROM_BLOB, blob + b'\0' * (-len(blob) % 4)),
    ]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w') as f:
        f.write('# Generated by tools/build.py - new code and changed bytes only (no original ROM data).\n')
        f.write('# Offsets are byte offsets in the big-endian (word-swapped back) view of u4.\n')
        f.write('ORIG_BOOT_LITERAL = 0x%08X\n' % MAIN_ENTRY)
        f.write('CHANGES = [\n')
        for off, data in changes:
            f.write('    (0x%06X, bytes.fromhex(\n' % off)
            h = data.hex()
            for i in range(0, len(h), 96):
                f.write('        %r\n' % h[i:i + 96])
            f.write('    )),\n')
        f.write(']\n')
    print('patch code %d bytes, loader %d bytes, %d literal hooks' % (len(blob), len(loader), len(table)))
    for k in sorted(HOOKS):
        print('  %-13s 0x%08X' % (k, syms[k]))
    print('wrote', OUT)


if __name__ == '__main__':
    main()
