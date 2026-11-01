# SDOJ Resurrected
## To Do
1. Adjust the bee medals so it's **10000PTS x hit**, with the last one being **10000PTS x hit x 2**
2. uncap the hit count
3. make all dresses expert mode and expert weapon
4. fix mra title name from SDOJ Resurrected (2012/ 4/20)
5. Add boss timers
6. add revenge bullets in hyper
   
## About this project
Why did I make this? Because it's fun and for my own personal research to see the capabilities of Claude.<br> 
While Claude was used I put effort in making sure there are balanced gameplay.<br> 
I did all the testing and planning.

## Patch Notes

### Title screen
There is no mode menu: insert a coin and press **START** to play Resurrected. After the announcer says "SAIDAIOUJOU", a gold **RESURRECTED** slides in at the bottom of the title screen. Attract demos also play as Resurrected.

### Boot and warning screens
The boot screen shows **SDOJ RESURRECTED 2026.10.30**, and the warning screen shows a short unofficial-project notice, **HAVE FUN!!!** and the date 2026/10/30 .

### Resurrected mode
- **Buttons**: buttons 1-3 work as in the original game (button 2 = bomb, or hyper when a hyper is ready). **Button 4 = bomb only**, so with a hyper ready you can bomb with button 4 and press button 2 during the bomb to go into hyper.
- **Expert weapon**: every dress uses the Expert shot and laser. You still pick your ship and dress, but the dress only changes the look.
- **Bombs**: **6 bomb slots** for every dress type; you start with **3 bombs** and each death gives **+1 bomb** (up to 6).
- **Bomb items** cancel all bullets on screen into big stars.
- **Hyper meter** fills **3 times as fast** as the original game outside hyper (death bonus unchanged). During a hyper nothing fills it (kills and laser hits add nothing); only hidden bees raise **HYPER Lv**.
- **GP bonus during hyper** by the hyper level at the start of the hyper (hypers spent): Lv1 x2.0, Lv2 x2.2, Lv3 x2.4, Lv4 x2.6, Lv5 x2.8, Lv6-10 x3.0 (original: x1.1-x1.5, then x2.2-x3.0). It stays the same until the hyper ends, even if HYPER Lv goes up.
- **Rank up to 999**: rank no longer stops at 50 (the HUD shows 3 digits). Up to 50 it works as in the original game; above 50 enemy bullets get faster: +0.2% per rank up to rank 100 (+10%), then +0.1% per rank (200 +20%, 500 +50%, 999 +99.9%), compared with rank 50. Rank still goes up with hypers and down with bombs.
- **Hyper ready voice**: the "HYPER SYSTEM READY" voice also plays whenever HYPER Lv goes up during a hyper.
- **Hidden bees**: every hidden bee shows **+100%** and gives exactly **one hyper** (max 10; no combo-based meter gain). During a hyper it raises **HYPER Lv** by 1 instead (the GP bonus stays as it was). Every bee also cancels all bullets into big stars.
- **Shot cancels bullets during hyper**: while a hyper is active, enemy bullets touched by your shot (not the laser) are cancelled into big stars.

## Patching the game
You need your own `ddpsdoj.zip` (MAME set, u4 CRC `e2a4411c`). The patched u4 has CRC `0a3ba4a8`.

The patched set is `ddpsdojdfk.zip`, with the patched u4 stored as `sdojdfk_u4`.
### Web patcher

open `patcher/index.html` (or the GitHub Pages copy), drop `ddpsdoj.zip` on it and download `ddpsdojdfk.zip`, the MiSTer `SDOJ Resurrected.mra`, or `sdojdfk_u4` alone. Everything runs locally in the browser.

### Python patcher

```
python3 patcher/sdoj_patch.py ddpsdoj.zip patched/ddpsdojdfk.zip
```

Only u4 changes (written as `sdojdfk_u4`); all other files are copied as they are. For MAME 0.289, which looks for `ddpsdoj.zip` with a file named `u4`, rename `sdojdfk_u4` to `u4` in a copy named `ddpsdoj.zip` (MAME will warn about the changed u4 checksum - that is expected).

Developers: `src/patch.s` is the SH-3 source; `python3 tools/build.py` (needs SH binutils such as `binutils-sh4-linux-gnu`) regenerates `patcher/sdoj_patch_data.py`; then `python3 tools/make_web.py ddpsdoj.zip` regenerates `patcher/index.html` and the .mra CRC. The patch adds a small boot loader in unused u4 space that copies the new code to free work RAM (0x0CE00000) and redirects a few code pointers in the unpacked program. Research notes are in `docs/ddpsdoj-notes.md`.

## Testing
This patch was tested with MAME 0.289 and [CV1k core for the MiSTer FPGA by Raki](https://www.patreon.com/c/ikamusume/posts)<br>
It may even work on a PCB but do so on your own risk.

## Credits

- [IAmTheChuckster](https://github.com/IAmTheChuckster)  project, testing
- [Claude](https://claude.ai) (Anthropic)  reverse engineering and patcher code
- Tested on the CV1k core for the MiSTer FPGA by [Raki](https://www.patreon.com/c/ikamusume/posts)

## Disclaimer

This repository contains a fan-made patch for research and technical analysis. The repository does not intentionally distribute the original game ROM, executable, or game assets. Users must obtain their own copy of the original game. This project is unofficial and is not affiliated with, endorsed by, or authorized by CAVE. All rights to the original game and its associated intellectual property remain with their respective rights holders. No license to third-party copyrighted material is granted by this repository.
