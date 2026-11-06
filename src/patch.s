! SDOJ Resurrected - SH-3 patch code for DoDonPachi SaiDaiOuJou (ddpsdoj, CV1000-D)
! Linked at 0x0CE00000 (free work RAM). Copied there at boot by loader.s.
! Big-endian SH-3. All hooks are reached by redirecting literal pointers in the game.

        .section .text
        .global _start
_start:

! ---------------------------------------------------------------- variables
        .org 0x000
v_mode:     .long 0     ! 0 = Arcade, 1 = 1.5+, 2 = SDOJ Resurrection (placeholder)
v_sel:      .long 0     ! title mode: 1 = Arrange, 0 = Original Arcade (default)
v_menu:     .long 0     ! 1 while the mode menu is shown on the title
v_nohyp:    .long 0     ! 1 = this bomb press must not start a hyper (button 4)
v_prevheld: .long 0     ! P1 held bits last title frame (edge detect)
v_grace:    .long 0     ! title frames without credit before the mode falls back to Arcade
v_sx:       .long 0     ! current shot x (16.16)
v_sy:       .long 0     ! current shot y (16.16)
v_inbee:    .long 0     ! 1 while the bee pickup routine runs (1.5+)
v_beeobj:   .long 0     ! bee pickup object (its +0xD8 is the % shown)
v_popup:    .long 0     ! 1 if the bee % popup was shown
v_hcnt:     .long 0     ! laser-hit counter during hyper (every 3rd hit counts)
v_lastdeaths: .long 0   ! player deaths seen last frame (1.5+ bombs)
v_lastbombs: .long 0    ! player bombs seen last frame
v_gpfix:    .long 0     ! GP bonus fixed at hyper start (0 = not set)
v_hudrank:  .long 0     ! real (uncapped) rank, shown on the HUD
v_lastlv:   .long 0     ! HYPER Lv seen last frame (voice)
v_tlast:    .long 0     ! frame counter at the last title frame
v_tstart:   .long 0     ! frame counter when the title started
v_tx:       .long -1    ! x of RESURRECTED on the title (-1 = hidden)
v_ncinit:   .long 0     ! proximity cancel: tables cleared
v_ncframe:  .long 0     ! proximity cancel: frame counter
v_ncprev:   .long 0     ! proximity cancel: bullets cancelled last frame (cascade seeds)
v_nobomb:   .long 0     ! 1 = button 2 pressed: it must never bomb (offset 92)
v_applied:  .long 1     ! mode written into the game (1 = Arrange) (offset 96)
v_tab:      .long 0     ! loader table for mode_apply, set by the loader (offset 100)

        .org 0x100
! ---------------------------------------------------------------- game addresses
        .equ ORIG_TITLE,   0x0C221070
        .equ ORIG_DS,      0x0C1DD4DC   ! draw string (x r4, y r5, colour r6, str r7)
        .equ ORIG_DN,      0x0C1DD990   ! draw number
        .equ ORIG_TRYBOMB, 0x0C212600   ! (obj r4, held r5, pressed r6)
        .equ ORIG_ACTHYP,  0x0C1FA0D0   ! ActivateHyper(p)
        .equ ORIG_GP,      0x0C1F8D40   ! GetGPBonus(p) -> percent
        .equ ORIG_KILL,    0x0C1FA320   ! GaugeEvent(p, amount, type)
        .equ ORIG_BEE,     0x0C22A8F0   ! hidden bee collected (item r4 ...)
        .equ SPAWN_HYPER,  0x0C1FA7D0   ! spawn hyper item(s) (p, count)
        .equ CANCEL,       0x0C1FD040   ! bullet cancel (type, p, big)
        .equ CREDITS,      0x0C1E112C
        .equ P1IN,         0x0C1DCD6C   ! +0 held

! ================================================================ title hook
! r4 = title object. Mode lines on the title: Original Mode (stock game) /
! Arrange Mode (this patch). Up/Down toggles. The choice rewrites the game's literal
! pointers and code patches (the loader table in u4) so Original is fully unpatched.
        .global title_hook
title_hook:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov     r4,r9
        mov.l   l_vars0,r1
        mov     #1,r0
        mov.l   r0,@(0,r1)          ! mode = 1 (hooks run only when patched in)
        mov     #0,r0
        mov.l   r0,@(8,r1)          ! no menu
        mov.l   l_p1in,r2
        mov.l   @r2,r3              ! held
        mov.l   @(16,r1),r5         ! previous held
        mov.l   r3,@(16,r1)
        not     r5,r5
        and     r5,r3               ! newly pressed
        mov     #3,r6               ! up (1) / down (2)
        tst     r6,r3
        bt      th_noin
        mov.l   @(4,r1),r0
        xor     #1,r0
        mov.l   r0,@(4,r1)          ! sel: 1 = Arrange, 0 = Original
th_noin:
        mov.l   @(4,r1),r8
        add     #96,r1
        mov.l   @r1,r2              ! applied mode
        cmp/eq  r8,r2
        bt      th_ok
        mov.l   r8,@r1
        mov.l   l_apply,r0
        jsr     @r0
        mov     r8,r4
th_ok:
        mov     r9,r4
        mov.l   l_orig_title,r0
        jsr     @r0
        nop
        mov.l   l_drawmode,r0
        jsr     @r0
        mov     #1,r4
        mov.l   l_setcol,r0         ! gold, game font
        mov.l   l_gold,r4
        jsr     @r0
        nop
        mov.l   l_s_or_on,r7        ! Original Mode
        tst     r8,r8
        bt      th_o1
        mov.l   l_s_or_off,r7
th_o1:  mov.w   w_my1,r5
        bsr     th_line
        mov     #60,r4
        mov.l   l_s_ar_off,r7       ! Arrange Mode
        tst     r8,r8
        bt      th_a1
        mov.l   l_s_ar_on,r7
th_a1:  mov.w   w_my2,r5
        bsr     th_line
        mov     #60,r4
        mov.l   l_setcol,r0
        mov.l   l_white,r4
        jsr     @r0
        nop
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
th_line:                            ! draw string r7 at (r4, r5)
        mov     #0x78,r6
        add     r6,r6               ! r6 = 0xF0
        mov.l   l_orig_ds,r0
        jmp     @r0
        nop

! r4 = 1 write the patched values, 0 write the original values (loader table)
        .global mode_apply
mode_apply:
        mov.l   l_vars0,r1
        add     #100,r1
        mov.l   @r1,r1              ! table (skips the title hooks)
ma_l:   mov.l   @r1+,r2             ! address (0 = end)
        tst     r2,r2
        bt      ma_e
        mov.l   @r1+,r3             ! original
        mov.l   @r1+,r5             ! patched
        mov.l   @r2,r6              ! current
        tst     r4,r4
        bt      ma_o
        cmp/eq  r3,r6
        bf      ma_l
        bra     ma_l
        mov.l   r5,@r2
ma_o:   cmp/eq  r5,r6
        bf      ma_l
        bra     ma_l
        mov.l   r3,@r2
ma_e:   rts
        nop

! ================================================================ HUD MAX
! The number drawer 0x0C27E880 packs digits 2 px tighter above its threshold
! (100,000,000). For the HUD MAX use 99,999, so 6-7 digits stay evenly spaced
! in the old 5-digit space. The threshold is restored after the call.
        .global maxnum_hook
maxnum_hook:
        sts.l   pr,@-r15
        mov.l   @(16,r15),r0        ! copy the 4 stack arguments
        mov.l   r0,@-r15
        mov.l   @(16,r15),r0
        mov.l   r0,@-r15
        mov.l   @(16,r15),r0
        mov.l   r0,@-r15
        mov.l   @(16,r15),r0
        mov.l   r0,@-r15
        mov.l   l_mthr,r1
        mov.l   l_m5,r0
        mov.l   r0,@r1
        mov.l   l_maxorig,r0
        jsr     @r0
        nop
        mov.l   l_mthr,r1
        mov.l   l_m8,r2
        mov.l   r2,@r1
        add     #16,r15
        lds.l   @r15+,pr
        rts
        nop
        .align 2
l_mthr:    .long 0x0C27E990
l_m5:      .long 99999
l_m8:      .long 100000000
l_maxorig: .long 0x0C27E880

! Stage-clear Hit Bonus: the tally pays 'hits x HITBONUS_MULT'. Without a cap that
! passes 4,294,967,295 (the most the 32-bit counters and the unsigned digit
! drawer can hold) around 429,496 hits. Wrap the hit getter used by the tally
! and clamp the count so the bonus stays at or under that limit.
        .global tally_hook
tally_hook:
        sts.l   pr,@-r15
        mov.l   l_tgo,r1
        jsr     @r1
        nop
        mov.l   l_tcap,r1
        cmp/hi  r1,r0
        bf      1f
        mov     r1,r0
1:      lds.l   @r15+,pr
        rts
        nop
        .align 2
l_tgo:      .long 0x0C1F8C60
l_tcap:     .long 429496

! ================================================================ big HIT counter
! Digit positions (x, y) for the big HIT number: the game's 5 slots, 21 px apart,
! extended to 8 so 6-7 digit counts keep the same even spacing.
        .align 2
        .global hit_slots
hit_slots:
        .long -92,108, -71,108, -50,108, -29,108, -8,108, 13,108, 34,108, 55,108

! ================================================================ draw string hook
! Replace the rank line and the two extend lines with the mode menu.
        .global ds_hook
ds_hook:                            ! hides the "1ST / 2ND" score-extend lines on the title
        mov.l   l_ext_lo,r0             ! (they overlap the mode lines); stays in both modes
        cmp/hs  r0,r7
        bf      ds_go
        mov.l   l_ext_hi,r0
        cmp/hs  r0,r7
        bt      ds_go
        rts
        nop
ds_go:
        mov.l   l_orig_ds,r0
        jmp     @r0
        nop

! ================================================================ draw number hook
! Hide the rank digit while the menu is shown (rank line is drawn at y 0xB7..0xB9).
        .global dn_hook
dn_hook:
        mov.l   l_vars0,r1
        mov.l   @(8,r1),r0
        tst     r0,r0
        bt      dn_go
        mov.w   w_yb6,r0
        cmp/ge  r0,r5
        bf      dn_go
        mov.w   w_yba,r0
        cmp/gt  r0,r5
        bt      dn_go
        rts
        nop
dn_go:
        mov.l   l_orig_dn,r0
        jmp     @r0
        nop

        .align 1
w_ylim: .word 0xCC
w_tvoice: .word 160
w_tx:   .word 108
w_my1:  .word 201
w_my2:  .word 213
w_b8:   .word 0xB8
w_tcol: .word 0xF0
w_grace: .word 240
w_c30:  .word 0xC30
w_yb6:  .word 0xB6
w_yba:  .word 0xBA
        .align 2
l_vars0:      .long v_mode
l_credits:    .long CREDITS
l_p1in:       .long P1IN
l_orig_title: .long ORIG_TITLE
l_fcount:     .long 0x0C5F7D60
l_setcol:     .long 0x0C1DD4B4
l_shadow:     .long 0x002A200A
l_textcol:    .long 0x00206080
l_white:      .long 0x00808080
l_gold:       .long 0x00806020
l_drawmode:   .long 0x0C1EBCC0
l_apply:      .long mode_apply
l_s_or_on:    .long s_or_on
l_s_or_off:   .long s_or_off
l_s_ar_on:    .long s_ar_on
l_s_ar_off:   .long s_ar_off
l_hudarc:     .long hud_arcade
l_rank_lo:    .long 0x0C30D590
l_rank_hi:    .long 0x0C30D5D8
l_ext_lo:     .long 0x0C315F00
l_ext_hi:     .long 0x0C315FC0
l_strtab:     .long strtab
l_orig_ds:    .long ORIG_DS
l_orig_dn:    .long ORIG_DN

! ================================================================ TryBomb hook
! obj r4, held r5, pressed r6. Also the per-frame place for 1.5+ bomb max.
        .global trybomb_hook
trybomb_hook:
        mov.l   l2_vars0,r1
        mov     #0,r0
        mov.l   r0,@(12,r1)         ! nohyp = 0
        mov     r1,r2
        add     #64,r2
        add     #28,r2
        mov.l   r0,@r2             ! nobomb = 0
        mov.l   @(0,r1),r0
        cmp/eq  #1,r0
        bf      tb_go
        ! --- 1.5+: max bombs 6 for every dress type
        mov.l   r5,@-r15            ! keep the held-input argument
        mov     r4,r2
        add     #0x70,r2
        mov.l   @r2,r2              ! player
        tst     r2,r2
        bt      tb_btn
        ! --- 1.5+: "HYPER SYSTEM READY" voice when HYPER Lv goes up
        mov.l   r2,@-r15
        mov.l   r4,@-r15
        mov.l   r6,@-r15
        sts.l   pr,@-r15
        mov.l   l2_hyplvframe,r0
        jsr     @r0
        mov     r2,r4
        lds.l   @r15+,pr
        mov.l   @r15+,r6
        mov.l   @r15+,r4
        mov.l   @r15+,r2
        mov.l   l2_vars0,r1
        ! --- 1.5+: always play as Expert (+0x10 = 2); the dress look (+0x14 ...) is kept
        mov     #2,r0
        mov.l   r0,@(16,r2)
        ! --- 1.5+ bombs: always 6 slots, start with 3, each death gives +1 bomb
        mov.w   w_3bb,r0
        mov.b   @(r0,r2),r3         ! deaths
        extu.b  r3,r3
        mov.l   @(48,r1),r0         ! deaths last frame
        cmp/hi  r0,r3
        bf      tb_nodeath
        mov.l   @(52,r1),r0         ! bombs before the death
        add     #1,r0
        bra     tb_setb
        nop
tb_nodeath:
        mov.b   @(7,r2),r0          ! max bombs
        cmp/eq  #6,r0
        bt      tb_keep
        mov     #3,r0               ! new game / continue: 3 bombs
tb_setb:
        mov     #6,r5
        cmp/gt  r5,r0
        bf      tb_set2
        mov     #6,r0
tb_set2:
        mov.b   r0,@(6,r2)
        mov     #6,r0
        mov.b   r0,@(7,r2)
tb_keep:
        mov.l   r3,@(48,r1)
        mov.b   @(6,r2),r0
        extu.b  r0,r0
        mov.l   r0,@(52,r1)
tb_btn:
        mov.l   @r15+,r5
        ! --- 1.5+: button 4 (0x80) = bomb only
        mov     r6,r0
        tst     #0x80,r0
        bt      tb_b2
        or      #0x20,r0
        mov     r0,r6
        mov     #1,r0
        mov.l   r0,@(12,r1)         ! nohyp = 1
tb_go:
        mov.l   l2_orig_trybomb,r0
        jmp     @r0
        nop
        ! --- 1.5+: button 2 (0x20) = hyper only
tb_b2:
        tst     #0x20,r0
        bt      tb_go
        mov     r4,r2
        add     #0x70,r2
        mov.l   @r2,r2              ! player
        tst     r2,r2
        bt      tb_go
        mov.w   w_tb2e0,r0
        mov.l   @(r0,r2),r3         ! in hyper?
        tst     r3,r3
        bt      tb_nohy
        ! in hyper: end it, cancel the bullets into small stars, no bomb
        mov.l   r4,@-r15
        mov.l   r5,@-r15
        mov.l   r6,@-r15
        sts.l   pr,@-r15
        mov.l   r2,@-r15
        mov.l   l_tb_end,r0
        jsr     @r0                 ! EndHyper(player): HYPER Lv back to 0
        mov     r2,r4
        mov.l   @r15,r5             ! player
        mov     #32,r4
        mov     #0,r6               ! flag 0 = small stars
        mov.l   l_tb_cancel,r0
        jsr     @r0
        nop
        mov.l   @r15+,r2
        lds.l   @r15+,pr
        mov.l   @r15+,r6
        mov.l   @r15+,r5
        mov.l   @r15+,r4
        bra     tb_drop
        nop
tb_nohy:
        mov.w   w_tb2e4,r0
        mov.l   @(r0,r2),r3         ! hyper stocks
        tst     r3,r3
        bt      tb_drop             ! no hyper ready: the press does nothing
        mov.l   l2_vars0,r1         ! hyper ready: start it, but never bomb
        add     #64,r1
        add     #28,r1
        mov     #1,r0
        mov.l   r0,@r1             ! nobomb = 1
        bra     tb_go
        nop
tb_drop:
        mov     r6,r0
        and     #0xDF,r0            ! ignore button 2 this frame
        mov     r0,r6
        bra     tb_go
        nop
        .align 2
w_tb2e0:    .word 0x2E0
w_tb2e4:    .word 0x2E4
l_tb_end:    .long 0x0C1FA250
l_tb_cancel: .long CANCEL

! TryBomb's bomb check (0x0C1F7ED0): refused while button 2 is the trigger
        .global bombgate_hook
bombgate_hook:
        mov.l   l_bg_vars,r1
        add     #64,r1
        add     #28,r1
        mov.l   @r1,r0
        tst     r0,r0
        bt      bg_orig
        rts
        mov     #0,r0
bg_orig:
        mov.l   l_bg_orig,r0
        jmp     @r0
        nop
        .align 2
l_bg_vars: .long v_mode
l_bg_orig: .long 0x0C1F7ED0

! ================================================================ ActivateHyper hook
        .global acthyp_hook
acthyp_hook:
        mov.l   l2_vars0,r1
        mov.l   @(12,r1),r0
        tst     r0,r0
        bt      ah_go
        rts
        mov     #0,r0
ah_go:
        mov.l   @(0,r1),r0
        cmp/eq  #1,r0
        bt      ah_15
        mov.l   l2_orig_acthyp,r0
        jmp     @r0
        nop
ah_15:                              ! 1.5+: rank limit 50, as the original
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov     r4,r8
        mov.w   w_2e4b,r0
        mov.l   @(r0,r8),r9         ! stocks before
        mov.w   w_2f0,r0
        mov.l   @(r0,r8),r10        ! rank before
        mov.l   l2_orig_acthyp,r0
        jsr     @r0
        nop
        tst     r0,r0
        bt      ah_ret
        mov     r0,r1
        mov     #11,r2
        cmp/hi  r2,r9
        bf      ah_idx
        mov     #11,r9
ah_idx: shll2   r9
        mov.l   l2_rankadd,r2
        add     r9,r2
        mov.l   @r2,r2
        add     r2,r10
        mov.w   w_999,r2
        cmp/gt  r2,r10
        bf      ah_set
        mov     r2,r10
ah_set: mov.w   w_2f0,r0
        mov.l   r10,@(r0,r8)
        mov     r1,r0
ah_ret: mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop

! ================================================================ GP bonus hook
! 1.5+: hyper GP bonus by hyper level: L1 2.0, L2 2.2, L3 2.4, L4 2.6, L5 2.8, L6-10 3.0,
! set when the hyper starts and kept until it ends.
        .global gp_hook
gp_hook:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov     r4,r8
        mov.l   l2_orig_gp,r0
        jsr     @r0
        nop
        mov.l   l2_vars0,r1
        mov.l   @(0,r1),r2
        mov     #1,r3
        cmp/eq  r3,r2
        bf      gp_ret
        mov     #100,r3
        cmp/eq  r3,r0
        bf      gp_boost
        mov     #0,r2
        bra     gp_ret              ! not boosted -> 1.0, clear the fixed value
        mov.l   r2,@(56,r1)
gp_boost:
        mov.l   @(56,r1),r2         ! already fixed for this hyper?
        tst     r2,r2
        bt      gp_calc
        bra     gp_ret
        mov     r2,r0
gp_calc:
        mov.w   w_2ec,r1
        add     r8,r1
        mov.l   @r1,r2              ! stocks spent at hyper start
        add     #-4,r1
        mov.l   @r1,r3              ! +0x2E8: HYPER Lv gained during the hyper (HUD)
        add     r3,r2               ! hyper level = start level + level-ups
        tst     r2,r2
        bt      gp_store
        mov     #5,r3
        cmp/gt  r3,r2
        bt      gp_max
        mov     #20,r3
        mulu.w  r3,r2
        sts     macl,r0
        mov.w   w_180,r3
        bra     gp_store
        add     r3,r0
gp_max:
        mov.w   w_300,r0
gp_store:
        mov.l   l2_vars0,r1
        mov.l   r0,@(56,r1)         ! GP stays at this value until the hyper ends
gp_ret:
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop

        .align 1
w_2ec:  .word 0x2EC
w_2e4b: .word 0x2E4
w_2f0:  .word 0x2F0
w_999:  .word 50      ! rank limit (the original game's)
w_3bb:  .word 0x3BB
w_180:  .word 180
w_300:  .word 300
        .align 2
l2_vars0:        .long v_mode
l2_orig_trybomb: .long ORIG_TRYBOMB
l2_orig_acthyp:  .long ORIG_ACTHYP
l2_orig_gp:      .long ORIG_GP
l2_rankadd:      .long 0x0C3387F0   ! rank added per hyper level
l2_hyplvframe:   .long hyplv_frame

! ================================================================ gauge event hook
! p r4, amount r5, type r6.  Gauge fills at the original rate (x1) outside hyper; during hyper nothing
! fills it (only bees raise HYPER Lv).
! During a bee pickup in 1.5+ the bee's own combo-based gauge gain is skipped.
        .global kill_hook
kill_hook:
        mov.l   l3_vars0,r1
        mov.l   @(0,r1),r0
        cmp/eq  #1,r0
        bf      kh_orig
        mov.l   @(32,r1),r0         ! inside bee pickup?
        tst     r0,r0
        bt      kh_nobee
        rts
        mov     #0,r0
kh_nobee:
        mov.w   w3_2e0,r0
        mov.l   @(r0,r4),r0         ! hyper active?
        tst     r0,r0
        bf      kh_inhyper          ! in hyper
kh_orig:                            ! not in hyper: original amount (x1)
        mov.l   l3_orig_kill,r0
        jmp     @r0
        nop
kh_inhyper:                         ! 1.5+ in hyper: kills and laser hits add nothing
        rts                         ! (only bees raise HYPER Lv)
        mov     #0,r0
kh_hyper:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov     r4,r8
        mov     r5,r9
        mov     r6,r10
        mov.l   l3_orig_kill,r0
        jsr     @r0                 ! the game's own in-hyper handling
        nop
        mov     r0,r11
        ! amount Arcade would give outside hyper (x1)
        mov     r10,r0
        cmp/eq  #3,r0
        bf      kh_t0
        mov.l   l3_vars0,r1         ! laser hits: +amount every 3rd hit
        mov.l   @(44,r1),r0
        add     #1,r0
        mov     #3,r2
        cmp/ge  r2,r0
        bt      kh_t3
        bra     kh_done
        mov.l   r0,@(44,r1)
kh_t3:  mov     #0,r0
        mov.l   r0,@(44,r1)
        bra     kh_add
        mov     r9,r2
kh_t0:  tst     r0,r0
        bf      kh_other
        mov.w   w3_3bc,r0           ! kills: A[deaths] + B[stock]
        mov.l   @(r0,r8),r0
        mov     #4,r3
        cmp/hi  r3,r0
        bf      kh_a
        mov     #4,r0
kh_a:   shll2   r0
        mov.l   l3_tblA,r3
        mov.l   @(r0,r3),r2
        mov.w   w3_2e4,r0
        mov.l   @(r0,r8),r0
        mov     #10,r3
        cmp/hi  r3,r0
        bf      kh_b
        mov     #10,r0
kh_b:   shll2   r0
        mov.l   l3_tblB,r3
        mov.l   @(r0,r3),r3
        bra     kh_add
        add     r3,r2
kh_other:
        mov     r9,r2
kh_add:
        mov     r8,r4               ! 0x0C1FA490: in-hyper meter, full bar -> HYPER Lv +1
        mov.l   l3_hyplv,r0
        jsr     @r0
        mov     r2,r5
kh_done:
        mov     r11,r0
        mov.l   @r15+,r11
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop

! ================================================================ hidden bee hook
! 1.5+: every bee shows 100%, gives exactly one hyper stock - or HYPER Lv +1 during a
! hyper - (no combo-based gauge)
! and cancels bullets into big stars.
        .global bee_hook
bee_hook:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   @(8,r4),r8          ! player
        mov.l   l3_vars0,r1
        mov.l   @(0,r1),r0
        cmp/eq  #1,r0
        bf      bee_arc
        mov     #1,r0
        mov.l   r0,@(32,r1)         ! inbee = 1
        mov.l   r6,@(36,r1)         ! bee object
        mov     #0,r0
        mov.l   r0,@(40,r1)         ! popup = 0
bee_arc:
        mov.l   l3_orig_bee,r0
        jsr     @r0
        nop
        mov     r0,r9
        mov.l   l3_vars0,r1
        mov.l   @(0,r1),r2
        mov     #1,r3
        cmp/eq  r3,r2
        bf      bee_ret
        mov     #0,r0
        mov.l   r0,@(32,r1)         ! inbee = 0
        tst     r8,r8
        bt      bee_ret
        ! show "100%" if the game skipped the popup (combo too low)
        mov.l   @(40,r1),r0
        tst     r0,r0
        bf      bee_stock
        mov.l   @(36,r1),r2
        mov.w   w3_d8,r0
        mov     #100,r3
        mov.l   r3,@(r0,r2)
        mov     r8,r4
        mov.l   l3_popup,r0
        jsr     @r0
        mov     #1,r5
bee_stock:
        mov.w   w3_2e0,r0
        mov.l   @(r0,r8),r0         ! in hyper?
        tst     r0,r0
        bt      bee_addstock
        ! in hyper: HYPER Lv +1 (HUD digit, +0x2E8), max 10
        mov     r8,r1
        mov.w   w3_2e4,r0
        add     r0,r1
        mov.l   @(4,r1),r2          ! +0x2E8
        mov     #10,r3
        cmp/ge  r3,r2
        bt      bee_cancel
        add     #1,r2
        bra     bee_cancel
        mov.l   r2,@(4,r1)
bee_addstock:
        mov.w   w3_2e4,r0
        mov.l   @(r0,r8),r2         ! hyper stock
        mov     #10,r3
        cmp/ge  r3,r2
        bt      bee_cancel
        add     #1,r2
        mov.l   r2,@(r0,r8)
bee_cancel:
        mov     #32,r4
        mov     r8,r5
        mov.l   l3_cancel,r0
        jsr     @r0
        mov     #1,r6
bee_ret:
        mov     r9,r0
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop

! bee "%" popup (0x0C2778E0), reached only from the bee pickup routine:
! in 1.5+ the shown value is always 100.
        .global popup_hook
popup_hook:
        mov.l   l3_vars0,r1
        mov.l   @(32,r1),r0
        tst     r0,r0
        bt      pp_go
        mov     #1,r0
        mov.l   r0,@(40,r1)         ! popup shown
        mov.l   @(36,r1),r2
        mov.w   w3_d8,r0
        mov     #100,r3
        mov.l   r3,@(r0,r2)
pp_go:
        mov.l   l3_popup,r0
        jmp     @r0
        nop

        .align 1
w3_2e0: .word 0x2E0
w3_d8:  .word 0xD8
w3_3bc: .word 0x3BC
w3_2e4: .word 0x2E4
w3_2f8: .word 0x2F8
w3_1ff: .word 0x1FF
w3_200: .word 0x200
        .align 2
l3_vars0:     .long v_mode
l3_orig_kill: .long ORIG_KILL
l3_orig_bee:  .long ORIG_BEE
l3_hyplv:     .long 0x0C1FA490   ! in-hyper meter / hyper level up
l3_cancel:    .long CANCEL
l3_popup:     .long 0x0C2778E0   ! bee % popup
l3_tblA:      .long 0x0C338848   ! kill gauge by deaths
l3_tblB:      .long 0x0C33881C   ! kill gauge by hyper stock


! ================================================================ bomb item (1.5+)
! 0x0C1F7D50 is called by the bomb item pickup (literal 0x0C22A508): cancel bullets into big stars.
        .global bombitem_hook
bombitem_hook:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov     r4,r8
        mov.l   bi_orig,r0
        jsr     @r0
        nop
        mov     r0,r9
        mov.l   bi_vars,r1
        mov.l   @r1,r0
        cmp/eq  #1,r0
        bf      bi_ret
        mov     #32,r4
        mov     r8,r5
        mov.l   bi_cancel,r0
        jsr     @r0
        mov     #1,r6
bi_ret: mov     r9,r0
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
        .align 2
bi_vars:   .long v_mode
bi_orig:   .long 0x0C1F7D50
bi_cancel: .long CANCEL

! ================================================================ always Expert (2.0)
! Player init sets +0x10 (dress type: 0 shot, 1 laser, 2 expert) through 0x0C1F7810.
! Forcing it here makes the whole game (stage setup, difficulty tables) see Expert from the start.
        .global dresstype_hook
dresstype_hook:
        mov     #2,r5
        mov.l   dt_orig,r0
        jmp     @r0
        nop
        .align 2
dt_orig: .long 0x0C1F7810

! Auto bomb (player +0x2C, set through 0x0C1F7850 at player init): forced on for every dress.
        .global autobomb_hook
autobomb_hook:
        mov     #1,r5
        mov.l   ab_orig,r0
        jmp     @r0
        nop
        .align 2
ab_orig: .long 0x0C1F7850

! ================================================================ dress select screen (2.0)
! The select screen draws its panels through five JSR literals (all 0x0C1E4990, sprite draw).
! Everything those five call sites draw is the description box (text per dress) and the
! dress-name / AUTO BOMB strip, except 0x13F59 (the character shadow): draw them far
! off screen instead (the weapon icon is drawn elsewhere and stays).
        .global dress_hook
dress_hook:
        sts     pr,r0
        mov.l   dh_p0,r1
        cmp/eq  r1,r0
        bt      dh_hide
        mov.l   dh_p1,r1
        cmp/eq  r1,r0
        bt      dh_hide
        mov.l   dh_p2,r1
        cmp/eq  r1,r0
        bt      dh_hide
        mov.l   dh_p3,r1
        cmp/eq  r1,r0
        bt      dh_hide
        mov.l   dh_p4,r1
        cmp/eq  r1,r0
        bf      dh_go
dh_hide:
        mov.l   dh_keep,r0
        cmp/eq  r0,r4
        bt      dh_go
        mov.l   dh_far,r5
dh_go:  mov.l   dh_orig,r0
        jmp     @r0
        nop
        .align 2
dh_p0:   .long 0x0C274656
dh_p1:   .long 0x0C274E02
dh_p2:   .long 0x0C274F54
dh_p3:   .long 0x0C2750A8
dh_p4:   .long 0x0C2751DE
dh_keep: .long 0x00013F59
dh_far:  .long 0xE0000000
dh_orig: .long 0x0C1E4990

! ================================================================ 1UP item (1.5+)
! 0x0C1F7470 (add a life) is called by the 1UP item pickup (literal 0x0C22A8CC): cancel bullets into big stars.
        .global life_hook
life_hook:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov     r4,r8
        mov.l   lh_orig,r0
        jsr     @r0
        nop
        mov     r0,r9
        mov.l   lh_vars,r1
        mov.l   @r1,r0
        cmp/eq  #1,r0
        bf      lh_ret
        mov     #32,r4
        mov     r8,r5
        mov.l   lh_cancel,r0
        jsr     @r0
        mov     #1,r6
lh_ret: mov     r9,r0
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
        .align 2
lh_orig:   .long 0x0C1F7470
lh_vars:   .long v_mode
lh_cancel: .long CANCEL


! ================================================================ proximity cancel
! Every frame (r4 = player): bullets that fly within 24 px of an enemy (any bullet
! emitter) turn into stars: small stars, or big stars while the player is in hyper. Bullets within 16 px
! of a bullet cancelled the frame before cancel too, so it ripples outwards.
! Emitters are the places bullets spawn at; they are remembered for 30 frames. A
! bullet never counts its own birthplace as an enemy, and bullets younger than 7
! frames are left alone.
! Work tables at NC (cleared on the first call):
!   +0x0000  1024 x 16: per bullet {age, spawn x, spawn y, -}   index = (addr >> 4) & 0x3FF
!   +0x4000  32 x 16:   emitters {x, y, last frame, -}
!   +0x4200  64 x 8:    cancelled last frame {x, y}
!   +0x4400  64 x 8:    cancelled this frame {x, y}
        .equ NC,        0x0CE10000
        .equ NC_EMIT,   0x4000
        .equ NC_PREV,   0x4200
        .equ NC_NEW,    0x4400
        .equ NC_SIZE,   0x4600
        .equ R24,       0x00180000
        .equ R16,       0x00100000
        .equ R8,        0x00080000
        .global nc_frame
nc_frame:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov.l   r12,@-r15
        mov.l   r13,@-r15
        mov.l   r14,@-r15
        mov     r4,r8                   ! player
        mov.l   nc_c_base,r14
        mov.l   nc_c_vars,r1
        add     #64,r1                  ! r1 = vars + 64 (displacements stay <= 60)
        mov.l   @(16,r1),r0             ! v_ncinit
        tst     r0,r0
        bf      nc_inited
        mov     #1,r0
        mov.l   r0,@(16,r1)
        mov     #100,r0
        mov.l   r0,@(20,r1)             ! frame counter starts at 100 (entry time 0 = empty)
        mov     #0,r0
        mov.l   r0,@(24,r1)
        mov     r14,r2                  ! clear the tables
        mov.w   nc_c_words,r3
nc_clr: mov.l   r0,@r2
        dt      r3
        bf/s    nc_clr
        add     #4,r2
nc_inited:
        mov.l   nc_c_vars,r1
        add     #64,r1
        mov.l   @(20,r1),r13
        add     #1,r13
        mov.l   r13,@(20,r1)            ! r13 = frame
        mov.w   nc_c_2e0,r0
        mov.l   @(r0,r8),r0             ! hyper active?
        tst     r0,r0
        movt    r11
        mov     #1,r1
        xor     r1,r11                  ! r11 = 1 in hyper = big stars, 0 = small stars
        mov     #0,r10                  ! bullets cancelled this frame
        mov.l   nc_c_mgr,r0
        mov.l   @r0,r1
        tst     r1,r1
        bt      nc_fin
        mov.l   nc_c_30dfc,r2
        add     r2,r1
        mov.l   @(28,r1),r0
        tst     r0,r0
        bt      nc_fin
        mov.l   @(20,r1),r9             ! first bullet
nc_loop:
        tst     r9,r9
        bt      nc_fin
        mov     r9,r0                   ! record = NC + ((node >> 4) & 0x3FF) * 16
        shlr2   r0
        shlr2   r0
        mov.w   nc_c_3ff,r1
        and     r1,r0
        shll2   r0
        shll2   r0
        mov     r14,r12
        add     r0,r12
        mov.l   @r9,r0                  ! state
        cmp/eq  #2,r0
        bt      nc_fly
        mov     #0,r0                   ! not flying: forget the bullet
        bra     nc_next
        mov.l   r0,@r12
nc_fly:
        mov.l   @(44,r9),r2             ! x
        mov.l   @(48,r9),r3             ! y
        mov.l   @r12,r0                 ! age
        tst     r0,r0
        bf      nc_old
        mov.l   r2,@(4,r12)             ! born: remember the birthplace
        mov.l   r3,@(8,r12)
        mov     #1,r0
        mov.l   r0,@r12
        bsr     nc_reg                  ! and note the emitter
        nop
        bra     nc_next
        nop
nc_old:
        add     #1,r0
        mov     #100,r1
        cmp/gt  r1,r0
        bf      nc_agok
        mov     r1,r0
nc_agok:
        mov.l   r0,@r12
        mov     #7,r1
        cmp/ge  r1,r0
        bf      nc_next                 ! too young
        mov.l   nc_c_r24,r6
        ! --- enemies (emitters seen in the last 30 frames)
        mov.w   nc_c_emit,r0
        mov     r14,r4
        add     r0,r4
        mov     #32,r7
nc_e1:  mov.l   @(8,r4),r0              ! last frame seen
        tst     r0,r0
        bt      nc_e9
        mov     r13,r1
        sub     r0,r1
        mov     #30,r0
        cmp/hi  r0,r1
        bt      nc_e9                   ! too old
        mov.l   @r4,r0                  ! ex
        mov     r2,r1
        sub     r0,r1
        cmp/pz  r1
        bt      1f
        neg     r1,r1
1:      cmp/ge  r6,r1
        bt      nc_e9
        mov.l   @(4,r4),r5              ! ey
        mov     r3,r1
        sub     r5,r1
        cmp/pz  r1
        bt      2f
        neg     r1,r1
2:      cmp/ge  r6,r1
        bt      nc_e9
        mov.l   @(4,r12),r1             ! was this bullet born at this enemy?
        sub     r0,r1
        cmp/pz  r1
        bt      3f
        neg     r1,r1
3:      cmp/ge  r6,r1
        bt      nc_hit                  ! born elsewhere in x: it is a visitor
        mov.l   @(8,r12),r1
        sub     r5,r1
        cmp/pz  r1
        bt      4f
        neg     r1,r1
4:      cmp/ge  r6,r1
        bt      nc_hit                  ! born elsewhere in y
nc_e9:  dt      r7
        bf/s    nc_e1
        add     #16,r4
        ! --- bullets cancelled last frame (cascade)
        mov.l   nc_c_vars,r1
        add     #64,r1
        mov.l   @(24,r1),r7
        tst     r7,r7
        bt      nc_next
        mov.w   nc_c_prev,r0
        mov     r14,r4
        add     r0,r4
        mov.l   nc_c_r16,r6
nc_p1:  mov.l   @r4,r0
        mov     r2,r1
        sub     r0,r1
        cmp/pz  r1
        bt      5f
        neg     r1,r1
5:      cmp/ge  r6,r1
        bt      nc_p9
        mov.l   @(4,r4),r0
        mov     r3,r1
        sub     r0,r1
        cmp/pz  r1
        bt      6f
        neg     r1,r1
6:      cmp/ge  r6,r1
        bf      nc_hit
nc_p9:  dt      r7
        bf/s    nc_p1
        add     #8,r4
        bra     nc_next
        nop
nc_hit:
        bsr     nc_cancel               ! r9 bullet, r8 player
        nop
        mov     #64,r0
        cmp/ge  r0,r10
        bt      nc_next
        mov.w   nc_c_new,r0             ! remember where it was
        mov     r14,r4
        add     r0,r4
        mov     r10,r0
        shll2   r0
        shll    r0
        add     r0,r4
        mov.l   @(44,r9),r0
        mov.l   r0,@r4
        mov.l   @(48,r9),r0
        mov.l   r0,@(4,r4)
        add     #1,r10
nc_next:
        bra     nc_loop
        mov.l   @(4,r9),r9
nc_fin:                                 ! this frame's cancels become the next frame's seeds
        mov.l   nc_c_vars,r1
        add     #64,r1
        mov.l   r10,@(24,r1)
        mov.w   nc_c_new,r0
        mov     r14,r4
        add     r0,r4
        mov.w   nc_c_prev,r0
        mov     r14,r5
        add     r0,r5
        mov     r10,r7
        tst     r7,r7
        bt      nc_ret
nc_cp:  mov.l   @r4+,r0
        mov.l   r0,@r5
        mov.l   @r4+,r0
        mov.l   r0,@(4,r5)
        dt      r7
        bf/s    nc_cp
        add     #8,r5
nc_ret: mov.l   @r15+,r14
        mov.l   @r15+,r13
        mov.l   @r15+,r12
        mov.l   @r15+,r11
        mov.l   @r15+,r10
        mov.l   @r15+,r9
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop
        .align 1
nc_c_words: .word NC_SIZE / 4
nc_c_2e0:   .word 0x2E0
nc_c_3ff:   .word 0x3FF
nc_c_emit:  .word NC_EMIT
nc_c_prev:  .word NC_PREV
nc_c_new:   .word NC_NEW
        .align 2
nc_c_base:  .long NC
nc_c_vars:  .long v_mode
nc_c_mgr:   .long 0x0C4C8978
nc_c_30dfc: .long 0x30DFC
nc_c_r24:   .long R24
nc_c_r16:   .long R16

! cancel one flying bullet into small stars - the body of the game's cancel routine
! (0x0C1FE220). r9 = bullet, r8 = player.
nc_cancel:
        sts.l   pr,@-r15
        mov     r9,r7
        add     #124,r7
        mov.l   nc_k_rel,r0
        jsr     @r0
        mov.l   @(48,r7),r4
        mov     r9,r7
        add     #124,r7
        mov     r9,r3
        add     #64,r3
        mov.l   @(36,r9),r2
        mov     #1,r1
        mov     #3,r4
        mov     #0,r5
        mov.l   r5,@(48,r7)
        mov.l   r4,@r9
        mov.l   r2,@(32,r9)
        mov.l   r5,@(24,r9)
        mov.l   r11,@(16,r3)            ! 0 = small stars (not in hyper), 1 = big stars (hyper)
        mov.l   r1,@(8,r3)
        mov.l   r1,@(12,r3)
        mov.l   r8,@(44,r7)
        lds.l   @r15+,pr
        rts
        nop
        .align 2
nc_k_rel:   .long 0x0C1E6A40

! note an emitter at (r2, r3): refresh the one within 8 px, else replace the oldest
nc_reg:
        mov.w   nc_r_emit,r0
        mov     r14,r4
        add     r0,r4
        mov     r4,r5                   ! oldest slot
        mov     #-1,r6
        shlr    r6                      ! oldest time = 0x7FFFFFFF
        mov     #32,r7
        mov.l   nc_r_r8,r1
        mov.l   r1,@-r15
nr_lp:  mov.l   @(8,r4),r0
        cmp/hi  r0,r6
        bf      nr_nold
        mov     r0,r6
        mov     r4,r5
nr_nold:
        tst     r0,r0
        bt      nr_nx                   ! empty slot
        mov.l   @r15,r1
        mov.l   @r4,r0
        sub     r2,r0
        cmp/pz  r0
        bt      1f
        neg     r0,r0
1:      cmp/ge  r1,r0
        bt      nr_nx
        mov.l   @(4,r4),r0
        sub     r3,r0
        cmp/pz  r0
        bt      2f
        neg     r0,r0
2:      cmp/ge  r1,r0
        bt      nr_nx
        mov     r4,r5                   ! same place: refresh this one
        bra     nr_set
        nop
nr_nx:  dt      r7
        bf/s    nr_lp
        add     #16,r4
nr_set: add     #4,r15
        mov.l   r2,@r5
        mov.l   r3,@(4,r5)
        rts
        mov.l   r13,@(8,r5)
        .align 1
nr_pad: .word 0
nc_r_emit:  .word NC_EMIT
        .align 2
nc_r_r8:    .long R8

! ================================================================ 1.5+ per-frame extras
! r4 = player. Plays the hyper-ready voice when HYPER Lv (+0x2E8) goes up and
! switches the HUD rank to 3 digits.
        .global hyplv_frame
hyplv_frame:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov     r4,r8
        mov.l   x_ncframe,r0        ! bullets near enemies cancel into stars (not in hyper)
        jsr     @r0
        nop
        mov.w   x_2e8,r0
        mov.l   @(r0,r8),r2         ! HYPER Lv now
        mov.l   x_vars,r1
        add     #64,r1
        mov.l   @r1,r3              ! last frame
        mov.l   r2,@r1
        cmp/gt  r3,r2
        bf      hx_ret
        mov.w   x_2e0,r0
        mov.l   @(r0,r8),r0         ! only during a hyper
        tst     r0,r0
        bt      hx_ret
        mov.l   x_se,r0             ! sound effect
        jsr     @r0
        nop
        mov     #9,r4               ! "HYPER SYSTEM READY" voice
        mov.l   x_voice,r0
        jsr     @r0
        mov     #70,r5
hx_ret: mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop

! Arcade: HUD rank back to the original 2 digits (called from the title hook).
        .global hud_arcade
hud_arcade:
        mov.l   x_hudcode,r1
        mov.l   x_hud2,r0
        mov.l   r0,@r1
        add     #-12,r1
        mov.l   x_hudx2,r0
        rts
        mov.l   r0,@r1

! rank index for the difficulty table stays 0..50; the HUD shows the real rank.
        .global getrank_hook
getrank_hook:
        sts.l   pr,@-r15
        mov.l   x_getrank,r0
        jsr     @r0
        nop
        mov.l   x_vars,r1
        mov.l   r0,@(60,r1)         ! HUD rank
        mov     #50,r2
        cmp/gt  r2,r0
        bf      gr_ret
        mov     r2,r0
gr_ret: lds.l   @r15+,pr
        rts
        nop

! bullet speed (1.5+): rank 51-100 +0.2% per rank (+10% at 100), then +0.1% per rank (+99.9% at 999). Hooks the speed-part call in
! the bullet spawn; the caller's r9 holds base speed + rank bonus at this point.
        .global speed_hook
speed_hook:
        sts.l   pr,@-r15
        mov.l   x_speedfn,r0
        jsr     @r0
        nop
        mov.l   x_vars,r1
        mov.l   @r1,r2
        mov     #1,r3
        cmp/eq  r3,r2
        bf      sp_ret
        mov.l   @(60,r1),r2         ! rank
        mov     #50,r3
        cmp/gt  r3,r2
        bf      sp_ret
        mov     #100,r3             ! extra per mille: 2*(rank-50) up to 100, then rank
        cmp/gt  r3,r2
        bt      sp_mul
        add     #-50,r2
        add     r2,r2
sp_mul:
        mov     r9,r3
        add     r0,r3
        add     #48,r3              ! speed the game is about to use
        mul.l   r2,r3
        sts     macl,r3
        mov.w   x_1000,r2
        mov.l   r0,@-r15
        mov     r3,r0
        mov     r2,r1
        mov.l   x_div,r3            ! r0 / r1
        jsr     @r3
        nop
        mov     r0,r3
        mov.l   @r15+,r0
        add     r3,r0
sp_ret: lds.l   @r15+,pr
        rts
        nop

! unsigned r0 / r1 -> r0 (simple, small values)
udiv:   mov     #0,r2
ud_l:   cmp/hs  r1,r0
        bf      ud_e
        sub     r1,r0
        bra     ud_l
        add     #1,r2
ud_e:   rts
        mov     r2,r0

! boot text (runs from the loader before the game starts)
        .global boot_init
boot_init:
        mov.l   x_vars,r1
        mov     #1,r0
        mov.l   r0,@r1              ! always Resurrected (attract demos too)
        mova    bt_tab,r0
        mov     r0,r4
bt_l:   mov.l   @r4+,r1             ! dest (0 = end)
        tst     r1,r1
        bt      bt_e
        mov.l   @r4+,r2             ! src
        mov.l   @r4+,r3             ! len
bt_c:   mov.b   @r2+,r0
        mov.b   r0,@r1
        dt      r3
        bf/s    bt_c
        add     #1,r1
        bra     bt_l
        nop
bt_e:   rts
        nop

        .align 1
x_2e8:  .word 0x2E8
x_2e0:  .word 0x2E0
x_1000: .word 1000
        .align 2
x_vars:    .long v_mode
x_ncframe: .long nc_frame
x_hudcode: .long 0x0C27ECD4
x_hud3:    .long 0x0009E703     ! nop / mov #3,r7
x_hud2:    .long 0xEA63E702     ! mov #99,r10 / mov #2,r7 (original)
x_hudx3:   .long 0x55E10009     ! x offset: full digit instead of half (0x0C27ECC8)
x_hudx2:   .long 0x55E14621     ! original
x_se:      .long 0x0C282860
x_voice:   .long 0x0C276900
x_getrank: .long 0x0C1F9F80
x_speedfn: .long 0x0C1F37A0
x_div:     .long udiv
bt_tab:
        .long 0x0C30D230, t_title, 26
        .long 0x0C30D25A, t_date, 10
        .long 0x0C30D268, t_warn, 416
        .long 0x0C30D408, t_wdate, 20
        .long 0
t_title: .ascii "    SaiDaiOuJou Arrange   "
t_date:  .ascii "2026.11.6 "
t_wdate: .ascii "           2026/11/6"
t_warn:
        .ascii "   THIS PROJECT IS UNOFFICIAL "
        .byte 0,0
        .ascii "   AND IS NOT AFFILIATED WITH,"
        .byte 0,0
        .ascii "   ENDORSED BY, OR AUTHORIZED "
        .byte 0,0
        .ascii "   BY CAVE. ALL RIGHTS TO THE "
        .byte 0,0
        .ascii "   ORIGINAL GAME AND ITS      "
        .byte 0,0
        .ascii "   ASSOCIATED INTELLECTUAL    "
        .byte 0,0
        .ascii "   PROPERTY REMAIN WITH THEIR "
        .byte 0,0
        .ascii "   RESPECTIVE RIGHTS HOLDERS. "
        .byte 0,0
        .ascii "                              "
        .byte 0,0
        .ascii "                              "
        .byte 0,0
        .ascii "          HAVE FUN!!!         "
        .byte 0,0
        .ascii "                              "
        .byte 0,0
        .ascii "                              "
        .byte 0,0
        .align 2

! ================================================================ menu text
        .align 2
strtab:    .long s_arc_on, s_arc_off, s_15_on, s_15_off, s_blank, s_blank
s_arc_on:  .asciz "> ARCADE"
s_arc_off: .asciz "  ARCADE"
s_15_on:   .asciz "> 1.5+"
s_15_off:  .asciz "  1.5+"
s_blank:   .asciz " "
s_or_on:   .asciz "> ORIGINAL ARCADE"
s_or_off:  .asciz "  ORIGINAL ARCADE"
s_ar_on:   .asciz "> ARRANGE MODE"
s_ar_off:  .asciz "  ARRANGE MODE"
        .align 2
_end:
