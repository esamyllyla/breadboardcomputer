ldx #$0
sleep:
cpx #$0a
inx
bne sleep

ldx #$14
jmp loop

.org $8040
array: ; clear display indeksillä 0xf
.byte $30,$38,$30,$38,$30,$38,$30,$20,$28,$20,$28,$20,
$80,$88,$00,$08,$00,$f0,$f8,$f0,$08,$00,$18,$10,$02,
$5a,$52,$4a,$42,$4a,$42,$5a,$52,$5a,$52,$2a,$22,$5a,
$52,$6a,$62,$4a,$42,$5a,$52,$20

.org $8fff ; täytetään ohjelmaa nollilla kun ei assembleri sitä itse tee
.byte $ea