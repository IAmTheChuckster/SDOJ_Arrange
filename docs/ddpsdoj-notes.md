# DoDonPachi SaiDaiOuJou (ddpsdoj) - research notes

MAME set `ddpsdoj`, CV1000-D (`cv1k_d`): 4 MB u4, 16 MB work RAM 0x0C000000-0x0CFFFFFF. Studied in MAME 0.289.
All addresses are RAM addresses of the unpacked program (original u4, CRC E2A4411C).

## Boot
- u4 is word-swapped in the dump. The boot ROM copies 0x51000 bytes to 0x0C000000, unpacks the rest
  of the program (0x0C002AC4), runs init 0x0C1DE514 and jumps to main 0x0C1E40D0 via the literal at
  u4 offset 0x1D8 (big-endian view). u4 is used only up to 0x2916CB; the rest is 0xFF.
- 0x0CB17000-0x0CFFEFFF stays zero during play (the patch uses 0x0CE00000).
- Lua write taps and debugger watchpoints only fire with `-nodrc`. Debugger commands work when set from
  Lua (`cpu.debug:bpset/wpset`) with `-debug -debugger none -log`.

## Controls (Arcade)
| Button | Action |
|---|---|
| 1 (A) | tap = shot, hold = laser |
| 2 (B) | bomb; if a hyper is stocked: hyper |
| 3 (C) | rapid-fire shot (auto shot) |
| 4 (D) | unused |

Input bits (P1 at 0x0C1DCD6C: +0 held, +0x10 newly pressed): Up 1, Down 2, Left 4, Right 8,
B1 0x10, B2 0x20, B3 0x40, B4 0x80, Start 0x8000. Credits: 0x0C1E112C.
Ship select: Type-A (Shuri, red), Type-B (Hikari, green), Type-C (Maria, blue), then dress select
(shot / laser / expert, auto-bomb on/off).

## Player structure (P1 at 0x0C5F9970)
| Offset | Meaning |
|---|---|
| +0x03 (byte) | lives (3 at start) |
| +0x06 / +0x07 (byte) | bombs / max bombs (+1 max per death, capped by dress type: 6/4/2) |
| +0x10 | dress type for gameplay: 0 shot, 1 laser, 2 expert (read via 0x0C1F7824); +0x14/+0x24/+0x1C0 also differ per dress (look) |
| +0x5C.. | score (big-number digits); pending score add at +0x54 |
| +0x1FC | current combo (hit chain), +0x200 combo bonus, +0x254 max combo |
| +0x2E0 | hyper active |
| +0x2E4 | hyper stock (max 10) |
| +0x2EC | hyper level = stocks spent at activation (1-10) |
| +0x2F0 | rank-like counter (+table per level, cap 50) |
| +0x2F4 | hypers used (cap 5) |
| +0x2F8 | normal gauge parked during hyper (restored when hyper ends) |
| +0x2FC | hyper gauge (full = 0x200); during hyper = hyper time left |
| +0x308 / +0x30C | hit-event counter / reload |
| +0x37C.. | hidden bee chain (+0x380, +0x384) |
| +0x3BC | deaths (index for the kill-gauge table) |

## Hyper gauge (Arcade)
- AddHyperGauge 0x0C1FA830: gauge += amount; above 0x1FF it subtracts 0x200 and drops a hyper item
  (0x0C1FA7D0). Collecting it adds 1 stock (0x0C1F9D90). With 10 stocks the gauge stops at 0x200.
- GaugeEvent 0x0C1FA320 (p, amount, type) feeds it outside hyper:
  - type 0, kills / hit milestones (via 0x0C1F6B90): amount = A[deaths] + B[stock]
    (tables 0x0C338848 / 0x0C33881C: 3 with no stock, 2 with 1-4 stock).
  - type 3, laser contact (0x0C21AA..): +1 every 3rd event.
  - death: +0x100 (half a bar) on respawn.
  - hidden bee (0x0C22A8F0): min(combo/50, 30) % of a bar, or a full bar on a completed chain.
- During hyper, GaugeEvent only drives hyper effects; the gauge does not fill.
- Measured with the same auto-play on every ship: about one hyper per 1500-2300 frames in stage 1
  (ship type does not change the rates).
- ActivateHyper 0x0C1FA0D0: spends all stocks (level = stocks), gauge parked at +0x2F8, gauge := 0x200
  and drains about 1 unit per 2 frames at level 1; cancels bullets (0x0C1FD040).

## GP bonus
GetGPBonus 0x0C1F8D40 returns percent: 100 outside hyper; in hyper 100 + 10*L (L <= 5) or 100 + 20*L (L >= 6).

## Bombs
TryBomb 0x0C212600 (obj, held, pressed): bomb mask 0x20 (button 2). With hyper stock it calls
ActivateHyper first (via the literal at 0x0C21291C), otherwise bombs. Hyper can be started during a bomb.
Bullet cancel 0x0C1FD040 (type, player, big): flag 1 = big stars (used by bombs in hyper).

## Title
TitleTextDraw 0x0C221070: rank line y=0xB8 ("  RANK  (NORMAL)" strings at 0x0C30D590..), extend lines
y=0xC8/0xD0 (strings at 0x0C315F04..). Draw string 0x0C1DD4DC (x, y, colour, str), draw number 0x0C1DD990.

## Patch hooks (SDOJ Resurrected)
Literal redirections (no code overwritten): title 0x0C221344/0x0C2222D4/0x0C222C88, draw string
0x0C2212AC/0x0C221308, draw number 0x0C2212B4, TryBomb 0x0C211C0C, ActivateHyper 0x0C21291C,
GP bonus 0x0C1F6E70/0x0C27AFFC/0x0C27C730/0x0C27D1B8, GaugeEvent 0x0C1F6C04/0x0C20B3E4/0x0C20B434/
0x0C21AC0C/0x0C22AAAC (death call 0x0C1F5E5C left alone), hidden bee 0x0C22A030.
Variables at 0x0CE00000: mode (always 1 = Resurrected; title shows a gold RESURRECTED slide via draw mode 0x0C1EBCC0(0) + colour 0x806020), menu cursor, menu flag, no-hyper flag.

## Dress select
- Task 0x0C274170 (literal 0x0C274100); data block from 0x0C1E62E0(task id). Block +0x1A8 = dress shown in the label/description (display only); the costume and the real choice are kept separately.
- Label/description images: tables 0x0C5B2740 / 0x0C5B2764 (ship*3 + dress; Expert entries are 0, drawn by a separate path).

## Objects, shots and bullets
- Object groups are updated by 0x0C216A70: each object's update routine is at obj+0xD8, next object at obj+0xDC;
  position x/y at obj+0x48/+0x4C (16.16), velocity +0x50/+0x54 (y grows upwards).
- Player shot update routines (4 per ship): Type-A 0x0C2173D0/217680/217A80/217DD0, Type-B 0x0C218160/2183C0/218770/2189F0,
  Type-C 0x0C218D80/218FE0/2193E0/2196B0 (each installed via one literal). The laser uses other routines (0x0C21AA..).
- Enemy bullets: list at [[0x0C4C8978]+0x30DFC]+0x14, next at +4, state +0 (2 = flying, 3 = cancelling),
  x/y at +0x2C/+0x30. 0x0C1FE220 (flag, player) cancels every state 1/2 bullet in that list (flag 1 = big stars).
- Hyper GP/HYPER Lv: +0x2E8 is the HUD HYPER Lv (level-ups during hyper via 0x0C1FA490); GP in Resurrected uses +0x2EC + +0x2E8.
- Chain x GP is computed in 32 bits (0x0C1F6ECC, 0x0C1F706E): it overflows above 2^31 / percent (original game; left as is).

## HIT counter
- Combo add 0x0C1F6C10 caps +0x1FC at 99999 (literal 0x0C1F6CE0); Resurrected raises it to 9,999,999.
- HUD HIT number 0x0C27DA..: value copied to HUD obj +0x70, digits from divisor 10000 (mov.w 0x0C27DC24, used at 0x0C27DAF0/0x0C27DB62); patched to mov.l 1000000 for 7 digits. Digit positions come from a 5-slot table 0x0C5B59DC (x -92..-8 step 21, y 108; literal 0x0C27DC34); Resurrected points it to an 8-slot copy.
- HUD MAX = player +0x278, drawn by number drawer 0x0C27E880 (call literal 0x0C27ADB4). The drawer packs digits 2 px tighter above 0x0C27E990 (100,000,000); Resurrected lowers that to 99,999 for the MAX call only.

## Stage-clear tally
- Tally state machine 0x0C290880.. : init reads the hit count through 0x0C1F8C60 (literal 0x0C290974) into the row struct (+4 remaining, +8 counted, +12 bonus total at 0x0C7D6414..). Each frame steps `r8` hits and adds `r8 x mult` to the total and the score (0x0C1F6D00). Case 4 is the Hit Bonus: multiplier mov.w at 0x0C290D1C (20000 literal 0x0C290DE6; Resurrected points it at the 10000 word 0x0C290DEA).
- The result number drawer 0x0C292450 divided by 10 with the signed 0x66666667 trick, so values >= 2^31 drew garbage. Resurrected makes it unsigned (dmulu.l, 0xCCCCCCCD, 3 logical shifts).
- Resurrected caps the hit count the tally reads at 429,496 (4,294,967,295 / 10,000), via a wrapper on literal 0x0C290974.

## Proximity cancel (Resurrected)
- Per frame from hyplv_frame (called by trybomb_hook): walks the bullet list; flying bullets (state 2) get an age and birth point in a table at 0x0CE10000 (index (node>>4)&0x3FF, nodes are 0x130 apart). First sight of a bullet registers its birth point as an emitter (32 slots, 30 frame life). Cancel = the body of 0x0C1FE220 (0x0C1E6A40 release, state 3, flag 0 = small stars, player at +0xA8 of the node+124).
- Hyper active = player +0x2E0 non-zero (no cancelling then). Gotcha: the assembler emits 4-byte SH2A forms for mov.l displacements over 60; keep them <= 60.

## Rank
- Player rank +0x2F0 (HUD RANK, 0..50): +table 0x0C3387F0[hypers spent] per hyper (0,1,1,2,2,3,3,4,4,5,5), -2 per bomb (0x0C1F9FD0).
- 0x0C661B48 = max player rank (via 0x0C1F9F80, literal 0x0C1FDD94); HUD draws it (0x0C27EC80, literal 0x0C27EDF0, 2 digits, cap 99).
- Difficulty D 0x0C4C897C = table 0x0C4C8768[rank] (0..30; +1 per rank to 10, then +1 per 2), x0.75 when nobody is in hyper,
  floor by table 0x0C4C8900, cap 50. D is added to every enemy bullet's speed at spawn (0x0C1FE5CC).
- Resurrected: rank to 999, table index kept at 50, bullet speed x(1 + (rank-50)/1000) via the speed-part call literal 0x0C1FE734.

## Sound
- Hyper stock increase (HUD task 0x0C213C74): 0x0C282860 (SE) + 0x0C276900(9,70) = "HYPER SYSTEM READY" voice.

## Open questions
- Exact meaning of the type 0 "hit milestone" counter (every 21 hits) vs. kill events.
- Bee chain completion rules (+0x384 > 7).
- Rank system (RANK on the HUD) not studied yet.

- Boot date string (t_date) and warning date (t_wdate, 20 characters, leading spaces centre it).

- Build 53: HIT limit back to the original 99999 (cap literal 0x0C1F6CE0, HUD digit patches and 8-slot table removed) and the Hit Bonus multiplier back to the original 20000 (max 1,999,980,000). The unsigned digit drawer and the tally hit-count cap (429,496) stay but no longer matter.
