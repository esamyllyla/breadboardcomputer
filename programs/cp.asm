; Control Program for 6502 breadboard computer

; LCD-control pin variables
E  = %1000
RS = %10
; LCD-display displays 2 or 4 lines
; set N to 1 for 4 lines, 0 for 2 lines
N = 1

; Keyboard matrix polling variables:
TMP = $0200
SHIFT = $0201
CURSOR_POSITION = $0202
TMP_KEYCODE = $0203

kb_polling_mode = $0204 ; 0 for continuous pollling, 1 for one time polling
; continuous polling polls until a keystroke occurs.
counter_var = $0205 ; DEBUG VARIABLE FOR DEBUG COUNTER PROGRAM
; counter_var + 1 = $0206 also in use

ascii_to_hex_temp = $0208

add8_prog_temp_var = $020a

MONITOR_LINE_1 = $0210 ; 16 characters each
                       ; so line 1 occupies 0x0210 - 0x021f etc
MONITOR_LINE_2 = $0220 ; 0x0220 - 0x022f
MONITOR_LINE_3 = $0230 ; 0x0230 - 0x023f
MONITOR_LINE_4 = $0240 ; 0x0240 - 0x24f

; User input interpreting variables:
COMMAND = $0250 ; "E" = Error, "R" = read, "W" = write
enter_pressed = $0251
tmp_input_byte = $0252
is_hex_letter = $0253
input_bytes_index = $0254
LOW_NYBBLE = $0255

RAL = $030 ; Read Address Low (pointer) for reading command   | POINTERS MUST BE ON ZERO PAGE
RAH = $031 ; Read Address High (pointer) for reading command  | ON 6502
input_bytes = $0260

; some program variables
addprog_oper1 = $0270
addprog_oper2 = $0271
addconvert_temp = $0272

    org $8000

    lda #$ff
    sta $6002
    lda #$f0
    sta $6003
    
    jsr init_lcd
    jsr init_monitor_memory

    ldx #$0
print_boot_msg:
    lda boot_msg, X
    jsr write_letter
    inx
    cpx #$5
    bne print_boot_msg
    jsr line_4
    
shell:
    jsr getline
    jsr interpret
    jsr run_command
    jsr printline
    jmp shell

endloop:
    jmp endloop

boot_msg:
    byte "R", "E", "A", "D", "Y"

init_monitor_memory:
    lda #$0
    ldx #$0
    sta SHIFT
    sta CURSOR_POSITION
    lda #" "
init_monitor_memory_loop:
    sta MONITOR_LINE_1, X
    sta MONITOR_LINE_2, X
    sta MONITOR_LINE_3, X
    sta MONITOR_LINE_4, X
    inx
    cpx #$10
    bne init_monitor_memory_loop
    rts

getline:
    lda #$0
    sta kb_polling_mode
continue_polling:
    jsr kb_poll
    jsr kb_encode
    lda enter_pressed
    cmp #$1
    bne continue_polling
    rts

kb_poll: ; keyboard polling
    lda #$0
    sta TMP_KEYCODE
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
    ora TMP
    sta TMP_KEYCODE
    rts
    jmp kb_index
kb_index:
    cpx #$4
    beq kb_end
    jmp kb_shft
kb_end:
    lda kb_polling_mode
    beq kb_poll
    rts

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
    lda #$1
    sta enter_pressed
; ==========================================
    jmp end_kb_encoded_write
skip_enter:
    lda #$0
    sta enter_pressed
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

interpret: ; Index register X is overwritten here
    pha
    lda #"!"
    sta COMMAND ; set Error (!) by default
    lda #$0
    sta LOW_NYBBLE ; start storing to high nybble
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
    cmp #"I"
    bne skip_was_counter
    sta COMMAND
    jmp inc_and_next
skip_was_counter:
    cmp #"J"
    bne skip_was_add8_prog
    sta COMMAND
    jmp inc_and_next
skip_was_add8_prog:
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
    lda #"!" ; SOME LETTER FOR ERROR
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
    lda COMMAND ; Commands are (R)ead, (W)rite, (E)xecute
    cmp #"R"
    bne skip_read
    jsr read
    jmp command_end
skip_read:
    cmp #"W"
    bne skip_write
    jsr write
    jmp command_end
skip_write:
    cmp #"E"
    bne skip_execute
    jsr execute
    jmp command_end
skip_execute:
    cmp #"I"
    bne skip_counter
    jsr counter
    jmp command_end
skip_counter:
    cmp #"J"
    bne skip_add8_prog
    jsr add8_prog
    jmp command_end
skip_add8_prog:
    cmp #"!"
    bne skip_throw_error
    jsr throw_error
    jmp command_end
skip_throw_error:
command_end:
    rts

read:
    jsr clear_line_4
    ldx #$0
    lda input_bytes
    jsr hex_to_ascii
    sta RAH
    lda input_bytes + 1
    inx
    jsr hex_to_ascii
    sta RAL
    inx
    lda #":"
    sta MONITOR_LINE_4, X
    inx
    lda #" "
    sta MONITOR_LINE_4, X
    inx
    ldy #$0
    lda (RAL), Y
    jsr hex_to_ascii
    rts

write:
    jsr clear_line_4
    lda input_bytes
    sta RAH
    lda input_bytes + 1
    sta RAL
    lda input_bytes + 2
    ldy #$0
    sta (RAL), Y
    jsr read
    rts

execute:
    jsr clear_line_4
    lda #"E"
    sta MONITOR_LINE_4
    jsr printline
    lda input_bytes
    sta RAH
    lda input_bytes + 1
    sta RAL
    jmp (RAL)

throw_error:
    jsr clear_line_4
    ldx #$0
write_error:
    lda error_msg, X
    sta MONITOR_LINE_4, X
    inx
    cpx #$5
    bne write_error
    rts

counter:
    jsr clear_line_4
    jsr line_4
    lda #$0
    sta TMP_KEYCODE
    lda #$1
    sta kb_polling_mode
    lda #$0
    sta counter_var
    sta counter_var + 1
continue_counter:
    lda counter_var
    clc
    adc #$1
    sta counter_var
    lda counter_var + 1
    adc #$0
    sta counter_var + 1
    ;cmp #$3a
    ;bne skip_reset_counter
    ;lda #$30
    ;sta counter_var
skip_reset_counter:
    jsr line_4
    ldx #$0
    lda counter_var + 1
    jsr hex_to_ascii  ;jsr write_letter
    ldx #$2
    lda counter_var
    jsr hex_to_ascii
    lda MONITOR_LINE_4
    jsr write_letter
    lda MONITOR_LINE_4 + 1
    jsr write_letter
    lda MONITOR_LINE_4 + 2
    jsr write_letter
    lda MONITOR_LINE_4 + 3
    jsr write_letter
    jsr longlonglong_sleep
    jsr kb_poll
    lda TMP_KEYCODE
    and #$0f
    beq continue_counter
    rts

add8_prog:
    lda #"A"
    sta MONITOR_LINE_4
    lda #"?"
    sta MONITOR_LINE_4 + 1
    jsr printline
    jsr getline ; getline stores input to MONITOR_LINE_4
    ldx #$0
    jsr ascii_to_hex ; 2 symbols of ascii converted to 8-bit hex and stored to accumulator
    sta add8_prog_temp_var
    lda #"B"
    sta MONITOR_LINE_4
    lda #"?"
    sta MONITOR_LINE_4 + 1
    jsr printline
    jsr getline
    ldx #$0
    jsr ascii_to_hex
    clc
    adc add8_prog_temp_var
    ldx #$0
    jsr hex_to_ascii
    jsr printline ; printline empties MONITOR_LINE_4
    ; shell currently calls printline after a program has returned
    rts

ascii_to_byte_w_index: ; in x-register, store index of ascii to fetch from monitor line 4 buffer
    ldy #$0
    lda #$0
    sta addconvert_temp
nybble_conversion:
    lda MONITOR_LINE_4, X
    eor #$30
    cmp #$0a
    bcc ascii_to_digit_w_index
    clc
    adc #$89
    cmp #$fa
    bcc ascii_to_byte_w_index_error
    and #$0f
ascii_to_digit_w_index:
    cpy #$1
    beq ascii_to_byte_w_index_no_shift
    asl
    asl
    asl
    asl
    and #$f0
    jmp ascii_to_byte_w_index_shift_done
ascii_to_byte_w_index_no_shift
    and #$0f
ascii_to_byte_w_index_shift_done:
    ora addconvert_temp
    sta addconvert_temp
    inx
    iny
    cpy #$2
    beq ascii_to_byte_w_index_end
    jmp nybble_conversion
ascii_to_byte_w_index_error:
    jsr throw_error
ascii_to_byte_w_index_end:
    rts

hex_to_ascii: ; hex stored in accumulator, cursor index stored in X-register
    ldy #$0
    pha
    lsr A
    lsr A
    lsr A
    lsr A
    and #$0f
convert_nybble:
    cmp #$a
    bmi nybble_to_number
    clc
    adc #$37
    jmp nybble_converted
nybble_to_number:
    clc
    adc #$30
nybble_converted:
    sta MONITOR_LINE_4, X
    cpy #$1
    beq hex_to_ascii_end
    pla
    pha
    and #$0f
    inx
    iny
    jmp convert_nybble
hex_to_ascii_end:
    pla
    rts

ascii_to_hex: ; hex stored in accumulator, cursor index stored in X-register
    ldy #$0
ascii_to_hex_loop:
    lda MONITOR_LINE_4, X
    EOR #$30
    cmp #$a
    bcc digit
    adc #$88
    cmp #$fa
    bcc nothex
digit:
    cpy #$1
    beq no_shift
    asl
    asl
    asl
    asl
    and #$f0
    sta ascii_to_hex_temp
    iny
    inx
    jmp ascii_to_hex_loop
no_shift:
    and #$0f
    ora ascii_to_hex_temp
nothex:
    rts

clear_line_4:
    ldx #$0
    lda #" "
continue_clear_line_4:
    sta MONITOR_LINE_4, X
    inx
    cpx #$10
    bne continue_clear_line_4
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

error_msg:
    byte "E", "R", "R", "O", "R"

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

init_lcd: ; ===== INIT_LCD START ===============
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
    lda #$10
    sta $6000
    jsr longlong_sleep
    lda #($10 | E)
    sta $6000
    jsr longlong_sleep
    lda #$10
    sta $6000
    jsr longlong_sleep

;; Set RS to data
    lda #RS
    sta $6000
    jsr longlong_sleep
    rts ; ===== INIT_LCD END ===============

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
    cpy #$14
    bne innerloop
    pla
    tay
    pla
    tax
    pla      ; pull accumulator back
    rts
innerloop:
    inx ; increment x
    cpx #$14
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

    org $8fff
    byte $ea
