# DoDonPachi SaiDaiOuJou Arrange
A patch for `DoDonPachi SaiDaiOuJou (Japan, 2012/ 4/20)`<br>
This repository holds only source, tools and notes. No ROM data is included; you patch your own legally owned dump

## About this project
Why did I make this? Because it's fun and for my own personal research to see the capabilities of Claude.<br> 
While Claude was used I put effort in making sure there are balanced gameplay.<br> 
I did all the testing and planning.

## Patch Notes

### Title screen
The title screen shows two gold lines, **Original Arcade** and **Arrange Mode**. Press Up or Down to move the arrow, then insert a coin and press **START**. Original Arcade plays the unpatched game (the normal ship and dress select, nothing changed); Arrange Mode (the default) plays this patch.

### Boot and warning screens
The boot screen shows **SaiDaiOuJou Arrange 2026.11.6**, and the warning screen shows a short unofficial-project notice, **HAVE FUN!!!** and the date 2026/11/6 .

### Changes
- **Buttons**: buttons 1 and 3 work as in the original game. **Button 2 = hyper only**: it starts a hyper when one is ready and does nothing otherwise (it never bombs). **Button 4 = bomb only**, so with a hyper ready you can bomb with button 4 and press button 2 during the bomb to go into hyper.
- **Ending a hyper**: press button 2 during a hyper to end it. All bullets on screen cancel into small stars and HYPER Lv goes back to 0 (no bomb is used).
- **Expert weapon**: every dress uses the Expert shot and laser. You still pick your ship and dress, but the dress only changes the look.
- **Bombs**: **6 bomb slots** for every dress type; you start with **3 bombs** and each death gives **+1 bomb** (up to 6).
- **Bomb items** cancel all bullets on screen into big stars.
- **1UP items** (e.g. the hidden one from the stage 4 mid boss) also cancel all bullets on screen into big stars when picked up (still untested in play).
- **Hyper meter** fills **3 times as fast** as the original game outside hyper (death bonus unchanged). During a hyper nothing fills it (kills, laser hits and stars add nothing); only hidden bees raise **HYPER Lv**.
- **GP bonus during hyper** by the hyper level at the start of the hyper (hypers spent): Lv1 x2.0, Lv2 x2.2, Lv3 x2.4, Lv4 x2.6, Lv5 x2.8, Lv6-10 x3.0 (original: x1.1-x1.5, then x2.2-x3.0). It stays the same until the hyper ends, even if HYPER Lv goes up.
- **Hyper ready voice**: the "HYPER SYSTEM READY" voice also plays whenever HYPER Lv goes up during a hyper.
- **Hidden bees**: every hidden bee shows **+100%** and gives exactly **one hyper** (max 10; no combo-based meter gain). During a hyper it raises **HYPER Lv** by 1 instead (the GP bonus stays as it was). Every bee also cancels all bullets into big stars.
- **Bullets cancel near enemies**: a bullet that flies within 24 px of an enemy (any bullet emitter) turns into a small star (a **big star** during hyper), and bullets within 16 px of one cancelled the frame before cancel too, so it ripples outwards. Bullets younger than 7 frames and a bullet's own birthplace don't count.

## Patching the game
You need your own **ddpsdoj.zip** (MAME set, DoDonPachi SaiDaiOuJou 2012/4/20) containing the original u4, u2, u23 and u24 files (u4 CRC `e2a4411c`). The patcher creates:

- `arr_u4` - the patched program ROM (CRC `2bf6f5e8`)
- `ddpsdojarr.zip` - your set with u4 replaced by `arr_u4`
- `DoDonPachi SaiDaiOuJou Arrange.mra` - the MiSTer MRA

### Web patcher
1. Open the [web patcher](https://iamthechuckster.github.io/SDOJ_Arrange/).
2. Load your `ddpsdoj.zip` (or a loose u4 file). Everything is processed in your browser and nothing is uploaded.
3. Check that the files show as OK.
4. Download **ddpsdojarr.zip**, **DoDonPachi SaiDaiOuJou Arrange.mra** and **arr_u4.zip** or **arr_u4**.

### Python script
Needs Python 3 and no extra packages. Download `sdoj_patch.py` and `sdoj_patch_data.py` into the same folder, then run:

```
python3 sdoj_patch.py ddpsdoj.zip --zip --mra
```

`--zip` writes `ddpsdojarr.zip`, `--mra` writes `DoDonPachi SaiDaiOuJou Arrange.mra` (it needs the .mra from this repository next to the script), and `-o FILE` sets the output path for `arr_u4`. A loose u4 can be given instead of the zip (without `--zip`).

### Using the patched files
- **MAME 0.289**: copy your `ddpsdoj.zip`, rename `arr_u4` to `u4` inside the copy, and run `mame ddpsdoj`. MAME will warn about the changed u4 checksum - that is expected.
- **MiSTer CV1k**: copy `ddpsdojarr.zip` to `games/mame` and `DoDonPachi SaiDaiOuJou Arrange.mra` to `_Arcade`.

Developers: `src/patch.s` is the SH-3 source; `python3 tools/build.py` (needs SH binutils such as `binutils-sh4-linux-gnu`) regenerates `sdoj_patch_data.py`; then `python3 tools/make_web.py ddpsdoj.zip` regenerates `index.html`, the .mra CRC and this README's CRC. The patch adds a small boot loader in unused u4 space that copies the new code to free work RAM (0x0CE00000) and redirects a few code pointers in the unpacked program. Research notes are in `docs/ddpsdoj-notes.md`.

## Testing
This patch was tested with MAME 0.289 and [CV1k core for the MiSTer FPGA by Raki](https://www.patreon.com/c/ikamusume/posts)<br>
It may even work on a PCB but do so on your own risk.

## Credits

- [IAmTheChuckster](https://github.com/IAmTheChuckster)  project, testing
- [Claude](https://claude.ai) (Anthropic)  reverse engineering and patcher code
- Tested on the CV1k core for the MiSTer FPGA by [Raki](https://www.patreon.com/c/ikamusume/posts)

## Disclaimer

This repository contains a fan-made patch for research and technical analysis. The repository does not intentionally distribute the original game ROM, executable, or game assets. Users must obtain their own copy of the original game. This project is unofficial and is not affiliated with, endorsed by, or authorized by CAVE. All rights to the original game and its associated intellectual property remain with their respective rights holders. No license to third-party copyrighted material is granted by this repository.
