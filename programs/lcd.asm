E  = %1000
RS = %10
LIM = $14

; LCD-display displays 2 or 4 lines
; set N to 1 for 4 lines, 0 for 2 lines
N = 1

; pointer for reading address
R_AL = $30
R_AH = $31

; Clear display
CLR = %10000

    org $8000 ;; SET TO 0 FOR EMULATOR
    ;cld ; use binary mode, thus clear decimal bit
    lda #$ff
    sta $6002
    lda #$f0
    sta $6003
    
    lda #$69
    sta $1010
    lda #$00
    sta $1011
    lda #$42
    sta $2020
    lda #$10
    sta R_AH
    sta R_AL
    
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
    
    jsr longlonglong_sleep
    jsr clear_display
    jsr line_4
    ;jsr longlonglong_sleep
    ;jmp message

TMP = $0200
SHIFT = $0205

CURSOR_POSITION = $0210

TMP_KEYCODE = $0215

MONITOR_LINE_1 = $0220 ; 16 characters each
                       ; so line 1 occupies 0x0220 - 0x022f etc
MONITOR_LINE_2 = $0230 ; 0x0230 - 0x023f
MONITOR_LINE_3 = $0240 ; 0x0240 - 0x024f
MONITOR_LINE_4 = $0250 ; 0x0250 - 0x25f

    lda #$0
    ldx #$0
    sta SHIFT
    sta CURSOR_POSITION
    lda #" "
init_monitor_memory:
    sta MONITOR_LINE_1, X
    sta MONITOR_LINE_2, X
    sta MONITOR_LINE_3, X
    sta MONITOR_LINE_4, X
    inx
    cpx #$10
    bne init_monitor_memory

kb_poll: ; keyboard polling
    lda #%00001000
    sta TMP
    ldx #$0
kb_shft:
    lda TMP
    asl
    inx
    sta TMP
    sta $6001 ; PORT A = 6001
    lda $6001  ; read PORT A, PORT A HANDLES KEYBOARD MATRIX, 4 lower bits are inputs,
               ; 4 higher bits are outputs
    and #$0f
    beq kb_index
    jsr kb_encode
    jmp kb_index

kb_index:
    cpx #$4
    beq kb_end
    jmp kb_shft

kb_end:
    jmp kb_poll

kb_encode:
    ora TMP
    sta TMP_KEYCODE
    ldx #$0
keycode_search:
    lda keycodes, X
    cmp TMP_KEYCODE
    beq kb_encoded_write
    inx
    cpx #$10
    bne keycode_search_continue
    rts
keycode_search_continue:
    jmp keycode_search

; NOTE:
;   kb_encode is a subroutine
;   it might return from kb_encode OR kb_encoded_write, 
;   but kb_encoded_write is not called with jsr even though it has rts and it is not a subroutine

kb_encoded_write:
    cpx #$f
    bne skip_clear
    lda CURSOR_POSITION
    cmp #$0
    beq end_kb_encoded_write
    sec
    lda CURSOR_POSITION
    sbc #$1
    sta CURSOR_POSITION
    tax
    lda #" "
    sta MONITOR_LINE_4, X
    jsr backspace
    jmp end_kb_encoded_write
skip_clear:
    cpx #$e
    bne skip_shift
    jsr update_shift
    jmp end_kb_encoded_write
skip_shift:
    cpx #$b
    bne skip_enter
; this happens when ENTER is pressed =======
    ;jsr printline
    jsr interpret
    jsr run_command
; ==========================================
    jmp end_kb_encoded_write
skip_enter:
    lda CURSOR_POSITION
    cmp #$10
    bne write_keyletter
    jmp end_kb_encoded_write
write_keyletter:
    lda CURSOR_POSITION
    clc
    adc #$1
    sta CURSOR_POSITION
    lda SHIFT         
    bne use_keyletters_2 ; if shift = 1, load letter from table keyletters_2
use_keyletters_1:
    lda keyletters, X
    ldy CURSOR_POSITION
    dey ; for some reason address MONITOR_LINE_4 + CURSOR POSITION is off to right by one??
    sta MONITOR_LINE_4, Y
    jsr write_letter
    jmp end_kb_encoded_write
use_keyletters_2:
    lda keyletters_2, X
    ldy CURSOR_POSITION
    dey
    sta MONITOR_LINE_4, Y
    jsr write_letter
end_kb_encoded_write:
    jsr longlonglong_sleep
    rts

COMMAND = $0270 ; "E" = Error, "R" = read, "W" = write
LOW_NYBBLE = $0271 ; For interpreter, if ascii is to be converted
                   ; to low or high nybble of a byte (0 or 1)

Arg0_H = $0272 ; Argument 0 used for read from location
Arg0_L = $0273
Arg1_H = $0274 ; Argument 1 used for read until this location
Arg1_L = $0275

Arg0_valid = $0276 ; throw error if these are invalid
Arg1_valid = $0277 ; in commands where they should be valid

input_bytes_index = $0278
tmp_input_byte = $0279
is_hex_letter = $0280

input_bytes = $0290

interpret: ; Index register X is overwritten here
    pha
    lda #"E"
    sta COMMAND ; set Error by default
    lda #$0
    sta LOW_NYBBLE ; start storing to high nybble
    sta Arg0_valid
    sta Arg1_valid
    sta Arg0_H
    sta Arg0_L
    sta Arg1_H
    sta Arg1_L ; initialize all variables to 0
    sta input_bytes_index
    sta is_hex_letter
    ldx #$0
clear_input_buffer:
    sta input_bytes, X
    inx
    cpx #$10
    bne clear_input_buffer
    ldx #$0
fetch_char:
    lda MONITOR_LINE_4, X
    cmp #" "
    beq inc_and_next
    cmp #"."
    bne skip_was_read
    lda #"R"
    sta COMMAND
    jmp inc_and_next
skip_was_read:
    cmp #":"
    bne skip_was_write
    lda #"W"
    sta COMMAND
    jmp inc_and_next
skip_was_write: ; character is supposed to represent hex
    cmp #"R"
    bne skip_was_run
    lda #"E" ; E as execute, now R is occupied for Read
    sta COMMAND
    jmp inc_and_next
skip_was_run:
    cmp #$30    ; 0x30 is "0", character should be equal or higher
    bmi invalid_hex ; if A - 30 is negative, BMI branches
    cmp #$47    ; 0x46 is "F", character should be equal or lower
    bpl invalid_hex ; if A - 47 is zero or positive, BPL branches
    cmp #$40
    bmi not_hex_letter
    ldy #$1
    sty is_hex_letter
    jmp is_letter_set
not_hex_letter:
    ldy #$0
    sty is_hex_letter
is_letter_set:
    jsr ascii_to_byte
    jmp inc_and_next
invalid_hex:
    lda #"E"
    sta COMMAND
inc_and_next:
    inx
    cpx #$10 ; increment until x >= 16
    bne fetch_char
interpret_end:
    pla
    rts

ascii_to_byte:
    ldy is_hex_letter
    cpy #$1
    beq is_a_to_f
    sec
    sbc #$30
    jmp store_temp
is_a_to_f:
    sec
    sbc #$37
store_temp:
    and #$0f
    sta tmp_input_byte
    ldy input_bytes_index
    lda input_bytes, Y
    asl A
    asl A
    asl A
    asl A
    and #$f0
    ora tmp_input_byte
    sta input_bytes, Y
    lda LOW_NYBBLE
    cmp #$1
    beq increment_byte_index
    lda #$1
    sta LOW_NYBBLE
    jmp end_ascii_to_byte
increment_byte_index:
    lda input_bytes_index
    clc
    adc #$1
    sta input_bytes_index
    lda #$0
    sta LOW_NYBBLE
end_ascii_to_byte:
    rts

run_command:
    pha
    ldx #$0
    stx LOW_NYBBLE
    jsr clear_line_4
debug_write_command:
    lda COMMAND
    sta MONITOR_LINE_4
    jsr printline
    ldx #$0
    ldy #$0
debug_write_bytes:
    lda LOW_NYBBLE
    cmp #$1
    beq skip_byte_shift
    lda #$1
    sta LOW_NYBBLE
    lda input_bytes, X
    lsr A
    lsr A
    lsr A
    lsr A
    and #$0f
    jmp byte_shifted
skip_byte_shift:
    lda #$0
    sta LOW_NYBBLE
    lda input_bytes, X
    and #$0f
    inx
byte_shifted:
    cmp #$a
    bmi to_number
    clc
    adc #$37
    jmp nybble_converted
to_number:
    clc
    adc #$30
nybble_converted:
    sta MONITOR_LINE_4, Y
    iny
    cpy #$10
    bne debug_write_bytes
    jsr printline
    lda COMMAND
    cmp #"R"
    bne skip_read
    jsr clear_line_4
    ldx #$1
    lda input_bytes
    sta R_AH
    lda input_bytes, X
    sta R_AL
    ldy #$0
    lda (R_AL), Y
    lsr A
    lsr A
    lsr A
    lsr A
    and #$0f
    cmp #$a
    bmi to_number_again
    clc
    adc #$37
    jmp high_nybble_converted
to_number_again:
    clc
    adc #$30
high_nybble_converted:
    sta MONITOR_LINE_4
    lda (R_AL), Y
    and #$0f
    cmp #$a
    bmi to_number_again_again
    clc
    adc #$37
    jmp low_nybble_converted
to_number_again_again:
    clc
    adc #$30
low_nybble_converted:
    sta MONITOR_LINE_4, X
    jsr printline
skip_read:
    cmp #"W"
    bne skip_write
    jsr clear_line_4
    lda input_bytes
    sta R_AH
    lda input_bytes + 1
    sta R_AL
    lda input_bytes + 2
    ldy #$0
    sta (R_AL), Y
    jsr printline
skip_write:
    cmp #"E"
    bne skip_execute
    lda input_bytes
    sta R_AH
    lda input_bytes + 1
    sta R_AL
    jmp (R_AL)
skip_execute:
    pla
    rts

clear_line_4:
    pha
    ldx #$0
clear_line_4_loop:
    lda #" "
    sta MONITOR_LINE_4, X
    inx
    cpx #$10
    bne clear_line_4_loop
    pla
    rts

printline: ; Index register X is overwritten here
    pha
    ldx #$0
read_line_traverse:
    lda MONITOR_LINE_2, X
    sta MONITOR_LINE_1, X
    lda MONITOR_LINE_3, X
    sta MONITOR_LINE_2, X
    lda MONITOR_LINE_4, X
    sta MONITOR_LINE_3, X
    inx
    cpx #$10 ; decimal 16, length of one line
    bne read_line_traverse
    jsr clear_display
    ldx #$0
print_line1:
    lda MONITOR_LINE_1, X
    jsr write_letter
    inx
    cpx #$10
    bne print_line1
    jsr line_2
    ldx #$0
print_line2:
    lda MONITOR_LINE_2, X
    jsr write_letter
    inx
    cpx #$10
    bne print_line2
    jsr line_3
    ldx #$0
print_line3:
    lda MONITOR_LINE_3, X
    jsr write_letter
    inx
    cpx #$10
    bne print_line3
    jsr line_4
    ldx #$0
print_empty_line4:
    lda #" "
    sta MONITOR_LINE_4, X
    jsr write_letter
    inx
    cpx #$10
    bne print_empty_line4
    jsr line_4
    lda #$0
    sta CURSOR_POSITION
    pla
    rts

update_shift:
    pha
    lda SHIFT
    bne no_shift_add ; If shift != 0, set to 0
    clc
    adc #$1          ; else set to 1
    jmp store_shift
no_shift_add:
    lda #$0
store_shift:
    sta SHIFT
    pla
    rts

backspace:
    pha
    jsr display_backspace
    lda #" "
    jsr write_letter
    jsr display_backspace
    pla
    rts

keycodes:
    byte $81, $11, $21, $41
    byte $12, $22, $42, $82
    byte $14, $24, $44, $84
    byte $18, $28, $48, $88

keyletters:
    byte "0", "1", "2", "3"
    byte "4", "5", "6", " "
    byte "7", "8", "9", "!"
    byte "/", "*", "-", "+"

keyletters_2:
    byte "A", "B", "C", "D"
    byte "E", "F", "G", "."
    byte "H", "I", "J", "K"
    byte "R", ":", ".", "+"

; lda 1000
; sta 6001, lda 6001 and 0f, beq write
; lda 0100
; sta 6001, lda 6001 and 0f, beq write
; lda 0010
; sta 6001, lda 6001 and 0f, beq write
; lda 0001
; sta 6001, lda 6001 and 0f, beq write

endloop:
    jmp endloop

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

line_2: ; 0x80 | 0x40 = 0xc0, 0x80: set DDRAM address, 0x40: DDRAM address for line 2 column 1
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

line_3: ; 0x80 | 0x10 = 0x90, 0x80: set DDRAM address, 0x10: DDRAM address for line 3 column 1
    pha
    lda #(($90 & $f0) | E)
    sta $6000
    jsr longlong_sleep
    lda #($90 & $f0)
    sta $6000
    jsr longlong_sleep
    lda #((($90 << 4) & $f0) | E)
    sta $6000
    jsr longlong_sleep
    lda #(($90 << 4) & $f0)
    sta $6000
    jsr longlong_sleep
    pla
    rts

line_4: ; 0x80 | 0x50 = 0xd0, 0x80: set DDRAM address, 0x50: DDRAM address for line 4 column 1
    pha
    lda #(($d0 & $f0) | E)
    sta $6000
    jsr longlong_sleep
    lda #($d0 & $f0)
    sta $6000
    jsr longlong_sleep
    lda #((($d0 << 4) & $f0) | E)
    sta $6000
    jsr longlong_sleep
    lda #(($d0 << 4) & $f0)
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

; x = 0
; y = 0
; outerloop:
; y++
; cpy lim
; bne innerloop
; ret
; innerloop:
; x++
; cpx lim
; bne innerloop
; jmp outerloop

    org $8fff
    byte $ea
