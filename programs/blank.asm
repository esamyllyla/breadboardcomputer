AH = $31 ; POINTERS HAVE TO BE ON ZERO PAGE
AL = $30 ; AL is at 0030, AH is at 0031

    org $0000
    lda #$42
    sta $0841
    lda #$41
    sta AL
    lda #$08
    sta AH
    ldy #$0
    lda (AL),Y

    ldx #$0
loop:
    inx
    cpx #$10
    bmi lessthan
    bpl morethan
    lda #$3 ; never gets here
    jmp loop
lessthan:
    lda #$1
    jmp loop
morethan:
    lda #$2
    jmp loop

endloop:
    jmp endloop
