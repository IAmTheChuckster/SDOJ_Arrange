! SDOJ Resurrected - SH-3 patch code for DoDonPachi SaiDaiOuJou (ddpsdoj, CV1000-D)
! Linked at 0x0CE00000 (free work RAM). Copied there at boot by loader.s.
! Big-endian SH-3. All hooks are reached by redirecting literal pointers in the game.

        .section .text
        .global _start
_start:

! ---------------------------------------------------------------- variables
        .org 0x000
v_mode:     .long 0     ! 0 = Arcade, 1 = 1.5+, 2 = SDOJ Resurrection (placeholder)
v_sel:      .long 0     ! menu cursor 0..2
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
! r4 = title object. Runs the mode menu while credits > 0.
        .global title_hook
title_hook:
        sts.l   pr,@-r15
        mov.l   r4,@-r15
        mov.l   l_vars0,r1
        mov.l   l_credits,r2
        mov.l   @r2,r0
        tst     r0,r0
        bf      th_menu
        ! no credit: normal title. Keep the chosen mode for a short grace period
        ! (the title is still drawn a few frames after START used the last credit),
        ! then fall back to Arcade so attract demos stay arcade.
        mov     #0,r0
        mov.l   r0,@(8,r1)          ! menu = 0
        mov.l   @(20,r1),r2
        tst     r2,r2
        bt      th_reset
        add     #-1,r2
        bra     th_call
        mov.l   r2,@(20,r1)
th_reset:
        bra     th_call
        mov.l   r0,@(0,r1)          ! mode = 0
th_menu:
        mov     #1,r0
        mov.l   r0,@(8,r1)          ! menu = 1
        mov.w   w_grace,r0
        mov.l   r0,@(20,r1)         ! grace = 240 frames
        ! show the title text (menu) right away: text-enable flag +0xC30 = 1,
        ! slide-in offset +0xC34 = 0
        mov.w   w_c30,r0
        mov     r4,r2
        add     r0,r2
        mov     #1,r0
        mov.l   r0,@r2
        mov     #0,r0
        mov.l   r0,@(4,r2)
        mov.l   l_p1in,r2
        mov.l   @r2,r3              ! held
        mov.l   @(16,r1),r5         ! prev held
        mov.l   r3,@(16,r1)
        not     r5,r5
        and     r5,r3               ! newly pressed
        mov.l   @(4,r1),r0          ! sel
        mov     r3,r5
        mov     #1,r6
        tst     r6,r5
        bt      th_noup
        add     #-1,r0
        cmp/pz  r0
        bt      th_noup
        mov     #1,r0
th_noup:
        mov     #2,r6
        tst     r6,r5
        bt      th_nodn
        add     #1,r0
        mov     #1,r6
        cmp/gt  r6,r0
        bf      th_nodn
        mov     #0,r0
th_nodn:
        mov.l   r0,@(4,r1)          ! sel
        mov.l   r0,@(0,r1)          ! mode = sel
th_call:
        mov.l   l_hudarc,r0
        jsr     @r0
        nop
        mov.l   @r15+,r4
        mov.l   l_orig_title,r0
        jmp     @r0                 ! tail call, pr restored below first
        lds.l   @r15+,pr

! ================================================================ draw string hook
! Replace the rank line and the two extend lines with the mode menu.
        .global ds_hook
ds_hook:
        mov.l   l_vars0,r1
        mov.l   @(8,r1),r0
        tst     r0,r0
        bt      ds_go
        mov.l   @(4,r1),r2          ! sel
        ! rank strings 0x0C30D590..0x0C30D5D7 -> line 0
        mov.l   l_rank_lo,r0
        cmp/hs  r0,r7
        bf      ds_ext
        mov.l   l_rank_hi,r0
        cmp/hs  r0,r7
        bt      ds_ext
        mov     #0,r3
        bra     ds_pick
        nop
ds_ext:
        mov.l   l_ext_lo,r0
        cmp/hs  r0,r7
        bf      ds_go
        mov.l   l_ext_hi,r0
        cmp/hs  r0,r7
        bt      ds_go
        mov     #1,r3
        mov.w   w_ylim,r0
        cmp/ge  r0,r5               ! y >= 0xCC -> second extend line
        bf      ds_pick
        mov     #2,r3
        add     #8,r5               ! move the last line down 8 px (16 px spacing)
ds_pick:
        ! index = line*2 + (sel==line ? 0 : 1)
        mov     r3,r0
        add     r0,r0
        cmp/eq  r2,r3
        bt      ds_sel
        add     #1,r0
ds_sel:
        shll2   r0
        mov.l   l_strtab,r1
        mov.l   @(r0,r1),r7
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
w_grace: .word 240
w_c30:  .word 0xC30
w_yb6:  .word 0xB6
w_yba:  .word 0xBA
        .align 2
l_vars0:      .long v_mode
l_credits:    .long CREDITS
l_p1in:       .long P1IN
l_orig_title: .long ORIG_TITLE
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
        bt      tb_go
        or      #0x20,r0
        mov     r0,r6
        mov     #1,r0
        mov.l   r0,@(12,r1)         ! nohyp = 1
tb_go:
        mov.l   l2_orig_trybomb,r0
        jmp     @r0
        nop

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
ah_15:                              ! 1.5+: rank goes past 50 (max 999)
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
w_999:  .word 999
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
! p r4, amount r5, type r6.  1.5+: gauge fills 3x outside hyper; during hyper it keeps
! filling at the normal Arcade amounts (x1) and raises HYPER Lv.
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
        bf      kh_hyper            ! in hyper
        mov     r5,r0               ! not in hyper: amount * 3
        add     r5,r5
        add     r0,r5
kh_orig:
        mov.l   l3_orig_kill,r0
        jmp     @r0
        nop
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


! ================================================================ shot vs bullet (1.5+ hyper)
! Each player-shot update routine (4 per ship) is redirected to a stub that runs the
! original update, then - in 1.5+ during hyper - cancels enemy bullets touching the shot.
! The laser uses other routines, so it does not cancel bullets.
        .global shot_stub0
        .align 2
shot_stub0:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C2173D0
        .global shot_stub1
        .align 2
shot_stub1:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C217680
        .global shot_stub2
        .align 2
shot_stub2:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C217A80
        .global shot_stub3
        .align 2
shot_stub3:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C217DD0
        .global shot_stub4
        .align 2
shot_stub4:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C218160
        .global shot_stub5
        .align 2
shot_stub5:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C2183C0
        .global shot_stub6
        .align 2
shot_stub6:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C218770
        .global shot_stub7
        .align 2
shot_stub7:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C2189F0
        .global shot_stub8
        .align 2
shot_stub8:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C218D80
        .global shot_stub9
        .align 2
shot_stub9:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C218FE0
        .global shot_stub10
        .align 2
shot_stub10:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C2193E0
        .global shot_stub11
        .align 2
shot_stub11:
        mov.l   1f,r1
        bra     shot_common
        nop
        .align 2
1:      .long   0x0C2196B0

        .align 2
shot_common:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   r9,@-r15
        mov.l   r10,@-r15
        mov.l   r11,@-r15
        mov.l   r12,@-r15
        mov.l   r13,@-r15
        mov     r4,r8
        jsr     @r1                 ! original shot update
        nop
        mov     r0,r13
        tst     r0,r0
        bt      sc_done             ! shot removed this frame
        mov.l   s_vars,r1
        mov.l   @r1,r0
        cmp/eq  #1,r0
        bf      sc_done             ! not 1.5+
        mov.l   s_player,r2
        mov.w   s_2e0,r0
        mov.l   @(r0,r2),r0
        tst     r0,r0
        bt      sc_done             ! not in hyper
        mov     r8,r2
        add     #0x48,r2
        mov.l   @r2+,r3             ! shot x
        mov.l   r3,@(24,r1)
        mov.l   @r2,r3              ! shot y
        mov.l   r3,@(28,r1)
        mov.l   s_bmgr,r9
        mov.l   @r9,r9
        tst     r9,r9
        bt      sc_done
        mov.l   s_mgroff,r0
        add     r0,r9               ! bullet manager
        mov.l   @(28,r9),r0
        tst     r0,r0
        bt      sc_done
        mov.l   @(20,r9),r10        ! first bullet
sc_loop:
        tst     r10,r10
        bt      sc_done
        mov.l   @r10,r0
        cmp/eq  #2,r0
        bf      sc_next
        mov.l   s_vars,r1
        mov     r10,r2
        add     #0x2C,r2
        mov.l   @r2+,r3             ! bullet x
        mov.l   @(24,r1),r0
        sub     r0,r3
        cmp/pz  r3
        bt      sc_ax
        neg     r3,r3
sc_ax:  mov.l   s_rad,r0
        cmp/gt  r0,r3
        bt      sc_next
        mov.l   @r2,r3              ! bullet y
        mov.l   @(28,r1),r0
        sub     r0,r3
        cmp/pz  r3
        bt      sc_ay
        neg     r3,r3
sc_ay:  mov.l   s_rad,r0
        cmp/gt  r0,r3
        bt      sc_next
        ! cancel just this bullet: make it the only list entry for the game's cancel routine
        mov.l   @(4,r10),r11        ! next
        mov.l   @(20,r9),r12        ! list head
        mov.l   r10,@(20,r9)
        mov     #0,r0
        mov.l   r0,@(4,r10)
        mov     #1,r4               ! big stars
        mov.l   s_player,r5
        mov.l   s_cancel1,r0
        jsr     @r0
        nop
        mov.l   r11,@(4,r10)
        mov.l   r12,@(20,r9)
        bra     sc_loop
        mov     r11,r10
sc_next:
        bra     sc_loop
        mov.l   @(4,r10),r10
sc_done:
        mov     r13,r0
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
s_2e0:  .word 0x2E0
        .align 2
s_vars:    .long v_mode
s_player:  .long 0x0C5F9970
s_bmgr:    .long 0x0C4C8978
s_mgroff:  .long 0x00030DFC
s_rad:     .long 0x000A0000     ! 10 px
s_cancel1: .long 0x0C1FE220     ! cancel bullets in the manager list (flag, player)

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

! ================================================================ 1.5+ per-frame extras
! r4 = player. Plays the hyper-ready voice when HYPER Lv (+0x2E8) goes up and
! switches the HUD rank to 3 digits.
        .global hyplv_frame
hyplv_frame:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov     r4,r8
        mov.l   x_hudcode,r1        ! HUD rank: 3 digits, no cap at 99
        mov.l   x_hud3,r0
        mov.l   r0,@r1
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

! bullet speed: above rank 50, +0.1% per rank (1.5+). Hooks the speed-part call in
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
        sub     r3,r2
        cmp/pl  r2
        bf      sp_ret
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
x_hudcode: .long 0x0C27ECD4
x_hud3:    .long 0x0009E703     ! nop / mov #3,r7
x_hud2:    .long 0xEA63E702     ! mov #99,r10 / mov #2,r7 (original)
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
t_title: .ascii "       SDOJ RESURRECTED   "
t_date:  .ascii "2026.10.30"
t_wdate: .ascii "          2026/10/30"
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
        .align 2
_end:
