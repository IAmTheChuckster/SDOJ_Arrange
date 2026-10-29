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
        mov     #2,r0
th_noup:
        mov     #2,r6
        tst     r6,r5
        bt      th_nodn
        add     #1,r0
        mov     #2,r6
        cmp/gt  r6,r0
        bf      th_nodn
        mov     #0,r0
th_nodn:
        mov.l   r0,@(4,r1)          ! sel
        mov.l   r0,@(0,r1)          ! mode = sel
th_call:
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
        bt      ds_l2
        bra     ds_pick
        add     #-4,r5              ! move the middle line up 4 px (even spacing)
ds_l2:
        mov     #2,r3
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
w_yb6:  .word 0xB6
w_yba:  .word 0xBA
        .align 2
l_vars0:      .long v_mode
l_credits:    .long CREDITS
l_p1in:       .long P1IN
l_orig_title: .long ORIG_TITLE
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
        mov     r4,r2
        add     #0x70,r2
        mov.l   @r2,r2              ! player
        tst     r2,r2
        bt      tb_btn
        mov.b   @(7,r2),r0          ! max bombs
        cmp/pz  r0
        bf      tb_btn
        mov     #6,r3
        cmp/ge  r3,r0
        bt      tb_btn
        sub     r0,r3               ! r3 = 6 - max (extra slots)
        mov     #6,r0
        mov.b   r0,@(7,r2)
        mov.b   @(6,r2),r0
        add     r3,r0
        mov     #6,r3
        cmp/gt  r3,r0
        bf      tb_bset
        mov     #6,r0
tb_bset:
        mov.b   r0,@(6,r2)
tb_btn:
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
        mov.l   l2_orig_acthyp,r0
        jmp     @r0
        nop

! ================================================================ GP bonus hook
! 1.5+: hyper GP bonus by hyper level: L1 2.0, L2 2.2, L3 2.4, L4 2.6, L5 2.8, L6-10 3.0
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
        bt      gp_ret              ! not boosted -> 1.0
        mov.w   w_2ec,r1
        add     r8,r1
        mov.l   @r1,r2              ! hyper level
        tst     r2,r2
        bt      gp_ret
        mov     #5,r3
        cmp/gt  r3,r2
        bt      gp_max
        mov     #20,r3
        mulu.w  r3,r2
        sts     macl,r0
        mov.w   w_180,r3
        bra     gp_ret
        add     r3,r0
gp_max:
        mov.w   w_300,r0
gp_ret:
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop

        .align 1
w_2ec:  .word 0x2EC
w_180:  .word 180
w_300:  .word 300
        .align 2
l2_vars0:        .long v_mode
l2_orig_trybomb: .long ORIG_TRYBOMB
l2_orig_acthyp:  .long ORIG_ACTHYP
l2_orig_gp:      .long ORIG_GP

! ================================================================ gauge event hook
! p r4, amount r5, type r6.  1.5+: gauge fills 3x; during hyper the stored gauge keeps filling.
        .global kill_hook
kill_hook:
        mov.l   l3_vars0,r1
        mov.l   @(0,r1),r0
        cmp/eq  #1,r0
        bf      kh_orig
        mov.w   w3_2e0,r0
        mov.l   @(r0,r4),r0         ! hyper active?
        tst     r0,r0
        bf      kh_hyper
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
        jsr     @r0
        nop
        mov     r0,r11              ! keep return value
        ! add = amount for type 3 (counted on every hit), amount*3 otherwise.
        ! Type 0 (kills) during hyper passes a smaller amount, so use the
        ! normal kill amount A[deaths] + B[stock] like outside hyper.
        mov     r9,r2
        mov     r10,r0
        cmp/eq  #3,r0
        bt      kh_add
        tst     r0,r0
        bf      kh_mul3
        mov.w   w3_3bc,r0
        mov.l   @(r0,r8),r0         ! deaths index
        mov     #4,r3
        cmp/hi  r3,r0
        bf      kh_a
        mov     #4,r0
kh_a:   shll2   r0
        mov.l   l3_tblA,r3
        mov.l   @(r0,r3),r2
        mov.w   w3_2e4,r0
        mov.l   @(r0,r8),r0         ! stock
        mov     #10,r3
        cmp/hi  r3,r0
        bf      kh_b
        mov     #10,r0
kh_b:   shll2   r0
        mov.l   l3_tblB,r3
        mov.l   @(r0,r3),r3
        add     r3,r2
        mov     r2,r9
kh_mul3:
        mov     r9,r2
        mov     r9,r3
        add     r3,r3
        add     r3,r2               ! amount*3
kh_add:
        mov.w   w3_2f8,r0
        mov.l   @(r0,r8),r3         ! stored gauge
        add     r2,r3
        mov.w   w3_1ff,r2
        cmp/gt  r2,r3
        bf      kh_store
        mov.w   w3_200,r2
        sub     r2,r3
        mov.l   r3,@(r0,r8)
        mov     r8,r4
        mov.l   l3_spawn,r0
        jsr     @r0                 ! drop a hyper item
        mov     #1,r5
        bra     kh_done
        nop
kh_store:
        mov.l   r3,@(r0,r8)
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
! 1.5+: every bee cancels bullets into big stars and adds one hyper stock.
        .global bee_hook
bee_hook:
        sts.l   pr,@-r15
        mov.l   r8,@-r15
        mov.l   @(8,r4),r8          ! player
        mov.l   l3_orig_bee,r0
        jsr     @r0
        nop
        mov.l   r0,@-r15
        mov.l   l3_vars0,r1
        mov.l   @(0,r1),r2
        mov     #1,r3
        cmp/eq  r3,r2
        bf      bee_ret
        tst     r8,r8
        bt      bee_ret
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
        mov.l   @r15+,r0
        mov.l   @r15+,r8
        lds.l   @r15+,pr
        rts
        nop

        .align 1
w3_2e0: .word 0x2E0
w3_3bc: .word 0x3BC
w3_2e4: .word 0x2E4
w3_2f8: .word 0x2F8
w3_1ff: .word 0x1FF
w3_200: .word 0x200
        .align 2
l3_vars0:     .long v_mode
l3_orig_kill: .long ORIG_KILL
l3_orig_bee:  .long ORIG_BEE
l3_spawn:     .long SPAWN_HYPER
l3_cancel:    .long CANCEL
l3_tblA:      .long 0x0C338848   ! kill gauge by deaths
l3_tblB:      .long 0x0C33881C   ! kill gauge by hyper stock

! ================================================================ menu text
        .align 2
strtab:    .long s_arc_on, s_arc_off, s_15_on, s_15_off, s_res_on, s_res_off
s_arc_on:  .asciz "> ARCADE"
s_arc_off: .asciz "  ARCADE"
s_15_on:   .asciz "> 1.5+"
s_15_off:  .asciz "  1.5+"
s_res_on:  .asciz "> SDOJ RESURRECTION"
s_res_off: .asciz "  SDOJ RESURRECTION"
        .align 2
_end:
