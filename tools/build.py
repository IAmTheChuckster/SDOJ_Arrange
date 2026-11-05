#!/usr/bin/env python3
"""Developer build: assemble src/patch.s, generate the boot loader, and write
sdoj_patch_data.py (changed u4 bytes only - no original ROM data).

Needs SH binutils (sh4-linux-gnu-as/ld/objcopy/nm, or sh-elf-*).
Usage: python3 tools/build.py
"""
import os, re, shutil, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'src')
OUT = os.path.join(ROOT, 'sdoj_patch_data.py')

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
    'popup_hook':   [0x0C22AAB0],
    'getrank_hook': [0x0C1FDD94],
    'speed_hook':   [0x0C1FE734],
    'v_hudrank':    [0x0C27EDF0],
    'bombitem_hook': [0x0C22A508],
    'tally_hook':  [0x0C290974],
    'life_hook':   [0x0C22A8CC],
    'bombgate_hook': [0x0C2127A0],
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
    0x0C22AAB0: 0x0C2778E0,
    0x0C1FDD94: 0x0C1F9F80,
    0x0C1FE734: 0x0C1F37A0,
    0x0C27EDF0: 0x0C661B48,
    0x0C22A508: 0x0C1F7D50,
    0x0C290974: 0x0C1F8C60,
    0x0C22A8CC: 0x0C1F7470,
    0x0C2127A0: 0x0C1F7ED0,
}

# plain value patches (address, original, new) - no hook code
CONSTS = [
    # generic digit drawer (stage-clear bonus etc.): signed /10 -> unsigned /10,
    # so values of 2^31 and above (Hit Bonus = hits x 20,000) draw correctly
    (0x0C292490, 0x348DE60A, 0x3485E60A),  #   dmuls.l -> dmulu.l
    (0x0C292498, 0x48214821, 0x48014801),  #   shar,shar -> shlr,shlr
    (0x0C29249C, 0x4A003AAA, 0x4801EA00),  #   shll,subc -> shlr, mov #0,r10
    (0x0C292524, 0x66666667, 0xCCCCCCCD),  #   divide-by-10 magic, unsigned
]


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


def loader_source(blob_len, table, init_addr):
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
        'done:   mov.l   l_init,r0         ! boot text etc.',
        '        jsr     @r0',
        '        nop',
        '        mov.l   l_main,r0',
        '        jmp     @r0',
        '        nop',
        '        .align 2',
        'l_src:  .long 0x%08X' % (0xA0000000 | ROM_BLOB),
        'l_dst:  .long 0x%08X' % RAM_BASE,
        'l_cnt:  .long %d' % words,
        'l_main: .long 0x%08X' % MAIN_ENTRY,
        'l_init: .long 0x%08X' % init_addr,
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
    table += CONSTS
    lsrc = os.path.join(tmp, 'loader.s')
    open(lsrc, 'w').write(loader_source(len(blob), table, syms['boot_init']))
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
