; idetest_v1.s - teste da CFFA v1.2 na RAM (Apple IIe Enhanced, 65C02), placa no slot 7
; 1) IDENTIFY do cartao: modelo, serial, firmware, capacidade
; 2) mede o laco de leitura original (status a cada word) x laco rapido (status 1x por setor)
;    lendo 256 setores a partir do LBA 0 (somente leitura). As linhas ">INICIO"/">FIM" recebem
;    a hora do PC na ponte (ms) -> tempo de cada laco.
; Montar: ca65 --cpu 65C02 idetest_v1.s && ld65 -t none -S $6000 idetest_v1.o -o idetest_v1.bin
        .setcpu "65C02"
        .org $6000

SLOT    = 7
IOB     = $C080 + SLOT*16
DATAH   = IOB+0
DATAL   = IOB+8
ERRREG  = IOB+9
SECCNT  = IOB+10
SECT    = IOB+11
CYL     = IOB+12
CYLH    = IOB+13
HEAD    = IOB+14
CMD     = IOB+15
STATUS  = IOB+15

COUT    = $FDED
CROUT   = $FD8E
PRBYTE  = $FDDA

PTR     = $06           ; ponteiro do buffer (2 bytes)
CNT     = $08
TMP     = $09
LBA0    = $EB
LBA1    = $EC
SUMLO   = $ED
SUMHI   = $EE
NSEC    = $EF

BUF     = $6800

start:  jsr msg
        .byte "CFFA TESTE V1 - SLOT 7",0
        jsr CROUT
        jsr identify
        bcs fail
        ; ---- laco original ----
        jsr msg
        .byte ">INICIO ORIGINAL",0
        jsr CROUT
        lda #0
        jsr bench
        bcs fail
        jsr msg
        .byte ">FIM ORIGINAL SOMA=",0
        jsr prsum
        ; ---- laco rapido ----
        jsr msg
        .byte ">INICIO RAPIDO",0
        jsr CROUT
        lda #1
        jsr bench
        bcs fail
        jsr msg
        .byte ">FIM RAPIDO SOMA=",0
        jsr prsum
        jsr msg
        .byte "OK",0
        jmp CROUT
fail:   jsr msg
        .byte "ERRO ST=",0
        lda STATUS
        jsr PRBYTE
        jsr msg
        .byte " ER=",0
        lda ERRREG
        jsr PRBYTE
        jmp CROUT

; ---------------- espera BSY=0 (com tempo maximo ~2 s) ----------------
waitrdy:
        ldx #0
        ldy #0
        lda #8
        sta TMP
@w:     lda STATUS
        bpl @ok
        dey
        bne @w
        dex
        bne @w
        dec TMP
        bne @w
        sec
        rts
@ok:    clc
        rts

; ---------------- IDENTIFY ----------------
identify:
        jsr waitrdy
        bcs @err
        lda #$E0
        sta HEAD
        lda #$EC
        sta CMD
        jsr waitrdy
        bcs @err
        lda STATUS
        and #$09
        cmp #$08
        beq @go
@err:   sec
        rts
@go:
        ldy #0
@l:     lda DATAL
        sta BUF,y
        lda DATAH
        sta BUF+1,y
        iny
        iny
        bne @l
@l2:    lda DATAL
        sta BUF+256,y
        lda DATAH
        sta BUF+257,y
        iny
        iny
        bne @l2
        jsr msg
        .byte "MODELO: ",0
        ldx #54
        ldy #20
        jsr prstr
        jsr msg
        .byte "SERIAL: ",0
        ldx #20
        ldy #10
        jsr prstr
        jsr msg
        .byte "FIRMWARE: ",0
        ldx #46
        ldy #4
        jsr prstr
        jsr msg
        .byte "SETORES (LBA, HEX): ",0
        lda BUF+123
        jsr PRBYTE
        lda BUF+122
        jsr PRBYTE
        lda BUF+121
        jsr PRBYTE
        lda BUF+120
        jsr PRBYTE
        jsr CROUT
        clc
        rts

; imprime Y words a partir do byte X do buffer (cada word: byte alto primeiro)
prstr:  lda BUF+1,x
        jsr pch
        lda BUF,x
        jsr pch
        inx
        inx
        dey
        bne prstr
        jmp CROUT
pch:    and #$7F
        cmp #$20
        bcs @p
        lda #'.'
@p:     ora #$80
        jmp COUT

; ---------------- benchmark: A=0 original, A=1 rapido ----------------
bench:  sta MODE
        stz LBA0
        stz LBA1
        stz SUMLO
        stz SUMHI
        stz NSEC                ; 256 setores
@sec:   jsr waitrdy
        bcc @s1
        rts
@s1:
        lda #$E0
        sta HEAD
        lda #1
        sta SECCNT
        lda LBA0
        sta SECT
        lda LBA1
        sta CYL
        stz CYLH
        stz DATAH
        lda #$20
        sta CMD
        jsr waitrdy
        bcs @r
        lda STATUS
        and #$09
        cmp #$01
        beq @e
        lda #<BUF
        sta PTR
        lda #>BUF
        sta PTR+1
        lda #2
        sta CNT
        ldy #0
        lda MODE
        bne @fast
; --- laco original do firmware 1.2: status a cada word ---
@lo:    lda STATUS
        bmi @lo
        and #$08
        beq @e
        lda DATAL
        sta (PTR),y
        iny
        lda DATAH
        sta (PTR),y
        iny
        bne @lo
        inc PTR+1
        dec CNT
        bne @lo
        bra @next
; --- laco rapido: status ja conferido 1x (DRQ) ---
@fast:  lda STATUS
        and #$08
        beq @e
@lf:    lda DATAL
        sta (PTR),y
        iny
        lda DATAH
        sta (PTR),y
        iny
        bne @lf
        inc PTR+1
        dec CNT
        bne @lf
@next:  clc                     ; soma simples dos 2 primeiros bytes de cada setor
        lda BUF
        adc SUMLO
        sta SUMLO
        lda BUF+1
        adc SUMHI
        sta SUMHI
        inc LBA0
        bne @n2
        inc LBA1
@n2:    dec NSEC
        beq @fim
        jmp @sec
@fim:
        clc
@r:     rts
@e:     sec
        rts

prsum:  lda SUMHI
        jsr PRBYTE
        lda SUMLO
        jsr PRBYTE
        jmp CROUT

; imprime string inline (terminada em 0) logo apos o JSR
msg:    pla
        sta PTR
        pla
        sta PTR+1
@m:     inc PTR
        bne @m2
        inc PTR+1
@m2:    lda (PTR)
        beq @d
        ora #$80
        jsr COUT
        bra @m
@d:     lda PTR+1
        pha
        lda PTR
        pha
        rts

MODE:   .byte 0
