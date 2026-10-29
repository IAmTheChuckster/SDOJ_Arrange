# SDOJ Resurrected

## To do
1. Create 1.5+ Mode based on 360 1.5
2. Create DFK-like arrange mode using 1.5+ mode as a base.
3. **Arrange**: expand to 6 bombs

   
## About this project
Why did I make this? Because it's fun and for my own personal research to see the capabilities of Claude.<br> 
While Claude was used I put effort in making sure there are balanced gameplay.<br> 
I did all the testing and planning.

## What it changes

### Mode select (title screen)
As soon as a coin is inserted, the title shows a mode menu in place of the rank and 1st/2nd extend lines:

```
> ARCADE
  1.5+
  SDOJ RESURRECTION
```

Use **Up / Down** to move the arrow and press **START** to play the selected mode. With no credits the title is unchanged, and attract demos always run in Arcade.

| Mode | Status |
|---|---|
| ARCADE | Unchanged original game |
| 1.5+ | Playable (see below) |
| SDOJ RESURRECTION | Placeholder - currently plays like Arcade |

### 1.5+ mode
- **Buttons**: buttons 1-3 work as in Arcade (button 2 = bomb, or hyper when a hyper is ready). **Button 4 = bomb only**, so with a hyper ready you can bomb with button 4 and press button 2 during the bomb to go into hyper.
- **Bombs**: maximum bombs raised to **6** for every dress type (shot, laser, expert); you start with 6.
- **Hyper meter** fills **3 times as fast** as Arcade (death bonus unchanged), and **keeps filling during hyper**: filling it during a hyper raises the HUD **HYPER Lv** (as in Arcade, just faster).
- **GP bonus during hyper** by hyper level (hypers spent to start it + HYPER Lv gained during it): Lv1 x2.0, Lv2 x2.2, Lv3 x2.4, Lv4 x2.6, Lv5 x2.8, Lv6-10 x3.0 (Arcade: x1.1-x1.5, then x2.2-x3.0, from hypers spent only).
- **Hidden bees**: every hidden bee cancels all bullets into big stars and adds **+1 hyper** (max 10).
- **Shot cancels bullets during hyper**: while a hyper is active, enemy bullets touched by your shot (not the laser) are cancelled into big stars.

## Patching the game
You need your own `ddpsdoj.zip` (MAME set, u4 CRC `e2a4411c`). The patched u4 has CRC `c3bea559`.

The patched set is `ddpsdojdfk.zip`, with the patched u4 stored as `sdojdfk_u4`.

**Browser:** open `patcher/index.html` (or the GitHub Pages copy), drop `ddpsdoj.zip` on it and download `ddpsdojdfk.zip`, the MiSTer `SDOJ Resurrected.mra`, or `sdojdfk_u4` alone. Everything runs locally in the browser.

**MiSTer:** put `ddpsdojdfk.zip` in your games folder and `patcher/SDOJ Resurrected.mra` in `_Arcade`.

**Python 3** (no extra packages):

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
