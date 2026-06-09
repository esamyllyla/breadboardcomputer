    
    org $8000
    lda #$ff
    sta $6002
    ldx #$00

loop:
    lda array,X
    sta $6000
    inx
    cpx #$2e
    bne loop

    ldx #$0

sleep:
    cpx #$0a
    inx
    bne sleep

    ldx #$0d
    jmp loop

    org $8040

array: ; clear display indeksillä 0xf
    byte $c0,$c8,$c0,$c8,$c0,$c8,$c0,$20,$28,$20,$28,$20,$00,$08,$00,$08,$00,$f0,$f8,$f0,$08,$00,$18,$10,$02,$5a,$52,$4a,$42,$4a,$42,$5a,$52,$5a,$52,$2a,$22,$5a,$52,$6a,$62,$4a,$42,$5a,$52,$20

    org $fffc ; täytetään ohjelmaa nollilla kun ei assembleri sitä itse tee
    word $8000
