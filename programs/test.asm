E  = %1000
RS = %10
LIM = $14

; LCD-display displays 2 or 4 lines
; set N to 1 for 4 lines, 0 for 2 lines
N = 1

; Clear display
CLR = %10000

    org $8000 ;; SET TO 0 FOR EMULATOR
    cld ; use binary mode, thus clear decimal bit
    lda #$ff
    sta $6002
    lda #$f0
    sta $6003
    
    ldx #$0

init_lcd:
    lda #($C << 4)
    sta $6000
    jsr longlong_sleep
    lda #(($C << 4) | E)
    sta $6000
    jsr longlong_sleep
    lda #($C << 4) ;; TODO: figure out if this enable low data signal is necessary
    sta $6000
    jsr longlong_sleep
    inx
    cpx #$3
    bne init_lcd
    
    ldx #$0

lcd_4bitmode: ; 4-bit
    lda #($2 << 4)
    sta $6000
    jsr longlong_sleep
    lda #(($2 << 4) | E)
    sta $6000
    jsr longlong_sleep
    lda #($2 << 4)
    sta $6000
    jsr longlong_sleep
    inx
    cpx #$2
    bne lcd_4bitmode

    ldx #$0

lcd_funset:
    lda #(N << 7)       ;;80
    sta $6000
    jsr longlong_sleep
    lda #((N << 7) | E) ;;88
    sta $6000
    jsr longlong_sleep
    lda #0   ;;(N << 7)   00
    sta $6000
    jsr longlong_sleep
    lda #E              ;;08
    sta $6000
    jsr longlong_sleep
    lda #0              ;;00
    sta $6000
    jsr longlong_sleep

lcd_dp_on:
    lda #($f << 4)
    sta $6000
    jsr longlong_sleep
    lda #(($f << 4) | E)
    sta $6000
    jsr longlong_sleep
    lda #($f << 4)
    sta $6000
    jsr longlong_sleep
    lda #$0
    sta $6000
    jsr longlong_sleep
    lda #$8
    sta $6000
    jsr longlong_sleep

lcd_clr_dp:
    lda #CLR
    sta $6000
    jsr longlong_sleep
    lda #(CLR | E)
    sta $6000
    jsr longlong_sleep
    lda #CLR
    sta $6000
    jsr longlong_sleep

;; Set RS to data
    lda #RS
    sta $6000
    jsr longlong_sleep

message:
    lda #"T"
    jsr write_letter
    lda #"E"
    jsr write_letter
    lda #"R"
    jsr write_letter
    lda #"V"
    jsr write_letter
    lda #"E"
    jsr write_letter

    jsr line_2
    lda #"M"
    jsr write_letter
    lda #"O"
    jsr write_letter
    lda #"R"
    jsr write_letter
    lda #"O"
    jsr write_letter

loop:
    jmp loop

write_letter:
    pha
    and #$f0   ; A &= 0xf0
    ora #RS    ; A |= RS
    ora #E     ; A |= E
    sta $6000
    jsr longlong_sleep
    and #$f0   ; A &= 0xf0
    ora #RS    ; A |= RS
    sta $6000
    jsr longlong_sleep
    pla ; pull original A value from stack
    pha ; push back immediately
    asl A
    asl A
    asl A
    asl A    ; A << 4
    and #$f0   ; A &= 0xf0
    ora #RS    ; A |= RS
    ora #E     ; A |= E
    sta $6000
    jsr longlong_sleep
    and #$f0   ; A &= 0xf0
    ora #RS    ; A |= RS
    sta $6000
    jsr longlong_sleep
    pla
    rts

clear_display:
    pha
    lda #(($1 & $f0) | E)
    sta $6000
    jsr longlong_sleep
    lda #($1 & $f0)
    sta $6000
    jsr longlong_sleep
    lda #((($c1 << 4) & $f0) | E)
    sta $6000
    jsr longlong_sleep
    lda #(($c1 << 4) & $f0)
    sta $6000
    jsr longlong_sleep
    pla
    rts

line_2:
    pha
    lda #(($c0 & $f0) | E)
    sta $6000
    jsr longlong_sleep
    lda #($c0 & $f0)
    sta $6000
    jsr longlong_sleep
    lda #((($c0 << 4) & $f0) | E)
    sta $6000
    jsr longlong_sleep
    lda #(($c0 << 4) & $f0)
    sta $6000
    jsr longlong_sleep
    pla
    rts

display_backspace:
    pha
    lda #(($10 & $f0) | E)
    sta $6000
    jsr longlong_sleep
    lda #($10 & $f0)
    sta $6000
    jsr longlong_sleep
    lda #((($10 << 4) & $f0) | E)
    sta $6000
    jsr longlong_sleep
    lda #(($10 << 4) & $f0)
    sta $6000
    jsr longlong_sleep
    pla
    rts

longlong_sleep:
    pha
    txa
    pha
    tya
    pha
    ldy #$0
outerloop:
    ldx #$0
    iny ; increment y
    cpy #LIM
    bne innerloop
    pla
    tay
    pla
    tax
    pla      ; pull accumulator back
    rts
innerloop:
    inx ; increment x
    cpx #LIM
    bne innerloop
    jmp outerloop

longlonglong_sleep:
    pha
    txa
    pha
    tya
    pha
    ldy #$0
louterloop:
    ldx #$0
    iny ; increment y
    cpy #$ff
    bne linnerloop
    pla
    tay
    pla
    tax
    pla      ; pull accumulator back
    rts
linnerloop:
    ;jsr longlong_sleep
    inx ; increment x
    cpx #$ff
    bne linnerloop
    jmp louterloop
