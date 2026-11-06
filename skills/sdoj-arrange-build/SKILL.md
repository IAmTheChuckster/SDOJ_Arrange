---
name: sdoj-arrange-build
description: Rebuild, extend, test (MAME 0.289) and release DoDonPachi SaiDaiOuJou Arrange, the CV1000 u4 patch with an Original Arcade / Arrange Mode title selector, from an original ddpsdoj dump.
---

# DoDonPachi SaiDaiOuJou Arrange - build skill

Repo: https://github.com/IAmTheChuckster/SDOJ_Arrange (main only). Use with the cv1000-patch-dev and
cv1000-learn-game skills for the MAME test setup.

## House rules
- No ROM data goes into any git repo or public artifact. Never commit `roms/` or `work/`.
- Everything on main. Push every build without asking. `git fetch` and rebase before pushing; the user edits
  README and the MRA upstream, so on a README conflict take the user's version.
- Commit trailers: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` and the `Claude-Session:` URL.
- Confirm changes with the user before starting. If interrupted, stop and wait.
- The chain x GP overflow above 21,474,836 is an original bug. Do not fix it.
- The MRA is the user's file: `DoDonPachi SaiDaiOuJou Arrange.mra` (spaces, no underscores), zip
  `ddpsdojarr.zip`, u4 part `arr_u4`. Only the part CRC changes per build (`tools/make_web.py` does it).

## Layout
- `src/patch.s` - SH-3 patch code (big-endian), linked at RAM 0x0CE00000 with variables at its start.
- `tools/build.py` - assembles, builds the u4 loader + blob. `HOOKS` = literal pointers redirected to our
  routines (checked against `ORIG`), `CONSTS` = (addr, orig32, new32) data/code patches. The first entries
  (`title_hook`, `ds_hook`) are permanent; the rest form the runtime table.
- `tools/make_web.py <original zip> <build>` - refreshes `index.html`, the MRA CRC, `sdoj_patch.py`
  PATCHED_CRC and the README CRC line. Writes `sdoj_patch_data.py` (patch bytes only, no ROM).
- `sdoj_patch.py` (Python patcher; writes `ddpsdojarr.zip` and the MRA) and `index.html` (web patcher).
- `docs/ddpsdoj-notes.md` - mechanics notes (player struct, gauge, bullets, select screen).

## Mode switch (build 61+)
- Title hook draws "ORIGINAL ARCADE" / "ARRANGE MODE" in the game font, gold, ">" marks the selection;
  Up/Down toggles (`v_sel` +4, 0 = Original Arcade default). The loader stores the runtime table address in
  `v_tab` (+100); `mode_apply` writes the original (r4=0) or patched (r4=1) value of every runtime entry
  (only if the current value matches the expected one). `v_applied` (+96) is what is currently written.
- Original Arcade = every hook, data patch and select-screen change reverted (stock game). Arrange = patch.
- The `1ST / 2ND` extend lines on the title are hidden in both modes (they overlap the mode lines).
- Any new hook or CONSTS entry is automatically covered by the mode switch.

## Arrange Mode content (current)
Expert dress for every dress (type forced at player init, auto bomb forced, select-screen description box and
AUTO BOMB strip hidden, weapon icon tables patched to the Expert icon), hyper gauge at the original 1x rate,
one hyper stock per bee, 1UP / chain / GP changes, rank HUD. See README for the full list.

## Build and test
1. `python3 tools/build.py` then `python3 tools/make_web.py <original ddpsdoj.zip> <build>`.
2. `mkdir /tmp/bldN; cd /tmp/bldN; python3 <repo>/sdoj_patch.py <original zip>` writes `arr_u4`. Put it with
   u2 u23 u24 into a zip in MAME's `roms_p/ddpsdoj.zip` (the original zip stays in `roms/`).
3. MAME 0.289 headless (cd to the MAME dir):
   `GAME=ddpsdoj ROMPATH=$PWD/roms_p HARNESS=lua/ddpsdoj_harness.lua BT_SCHED=<sched> BT_HOOK=<lua> BT_SNAP=<n> timeout N scripts/run.sh FRAMES`.
   Schedules use absolute frames and key names (K coin, S start, A, D, L, R, "-" release).
   Title is visible roughly f3700-4000; coin at ~4000, start ~4100, ship select ~4300, dress select ~4420.
4. Check: both modes on the title (arrow moves with Down), Original Arcade reaches the stock select screen,
   a Lua hook reading the runtime table (RAM 0x0CE00064 holds its ROM address; read it with `& 0x1FFFFFFF`)
   shows all entries original in Original Arcade and all patched in Arrange.
5. Commit, fetch and rebase, push to main, send the MRA to the user.

## Gotchas
- `mov.l @(disp,Rn)` disp <= 60 (use `add #n` first); PC-relative literals can't reach backward, so each hook
  needs its own pool.
- Do not `pkill -f`; kill MAME by PID.
- MAME debug mode (`-debug`) is needed for breakpoints and saved states may contain old patched code.
