; gravador_v2.s - grava um banco da EEPROM X28C256 da CFFA (slot 7) recebendo os dados pela serial
; Apple IIe Enhanced (65C02), Super Serial no slot 1 (19200 8N1 pelas chaves), CPLD v1.6.1.
; 2026-11-20
;
; Uso (pela ponte, modo #raw):  6000G  e depois  #sendbin rom\ARQUIVO.bin 256
;   ARQUIVO.bin = 2048 bytes = conteudo de $C700-$CEFF do banco (offsets $700-$EFF da imagem de 4 KB).
;   $6003 = banco: 0 -> banco do A14=0 (acesso a $C0F4) ; 1 -> banco do A14=1 (acesso a $C0F5)
;   v2: normalmente nao grava nem confere $CE80-$CEFF (preserva a montagem); $80/$81 = gravar tudo
; Protocolo: manda ACK ($06), recebe 256 bytes, repete 8 vezes. ESC no teclado do Apple cancela.
; Depois: grava byte a byte so o que for diferente (escrita simples + espera pelo "data polling"),
; trava a gravacao, confere os 2048 bytes, volta ao banco 0 e imprime o resumo.
; Nada e escrito fora de $C700-$CEFF.
        .setcpu "65C02"
        .org $6000

SSCDAT  = $C098         ; 6551 da Super Serial no slot 1
SSCST   = $C099
KBD     = $C000
KBDSTRB = $C010
COUT    = $FDED
CROUT   = $FD8E
PRBYTE  = $FDDA

EE_WEON  = $C0F3        ; escrita = destrava ; leitura = trava (CFFA slot 7)
EE_BANK0 = $C0F4        ; A14 = 0
EE_BANK1 = $C0F5        ; A14 = 1

PTR     = $06           ; endereco na ROM da placa ($C700..$CEFF)
SRC     = $08           ; endereco no buffer
BUF     = $7000         ; 2048 bytes

        jmp inicio
BANCO:  .byte 1         ; $6003
NGRAV:  .word 0         ; bytes gravados
NIGUAL: .word 0         ; bytes que ja estavam certos
NERRO:  .word 0         ; bytes que nao confirmaram a gravacao
NDIF:   .word 0         ; diferencas na conferencia final
SOMA:   .word 0         ; soma dos 2048 bytes recebidos

inicio: sei
        lda SSCDAT              ; descarta lixo na recepcao
        stz NGRAV
        stz NGRAV+1
        stz NIGUAL
        stz NIGUAL+1
        stz NERRO
        stz NERRO+1
        stz NDIF
        stz NDIF+1
        stz SOMA
        stz SOMA+1
; ---------- recepcao: 8 blocos de 256 ----------
        lda #<BUF
        sta SRC
        lda #>BUF
        sta SRC+1
        ldx #8
@blk:   lda #$06
        jsr envia
        ldy #0
@byte:  jsr recebe
        bcc @rx
        jmp cancela
@rx:    sta (SRC),y
        clc
        adc SOMA
        sta SOMA
        bcc @s1
        inc SOMA+1
@s1:    iny
        bne @byte
        inc SRC+1
        dex
        bne @blk
; ---------- escolhe o banco e liga a ROM da placa ----------
        lda $CFFF               ; solta o $C800 de todas as placas
        lda BANCO
        and #$7F
        beq @b0
        lda EE_BANK1
        bra @b1
@b0:    lda EE_BANK0
@b1:    jsr espera              ; ~2 ms para o A14 assentar
        lda $C700               ; liga o $C800 da CFFA
        sta EE_WEON             ; destrava a gravacao
; ---------- gravacao byte a byte ----------
        jsr inicio_ptr
@g:     lda (SRC)
        cmp (PTR)
        beq @igual
        sta (PTR)               ; grava (65C02: sem leitura falsa)
        ldx #0
        ldy #0
@poll:  lda (PTR)
        cmp (SRC)
        beq @ok
        dex
        bne @poll
        dey
        bne @poll
        inc NERRO               ; nao confirmou em ~1 s
        bne @prox
        inc NERRO+1
        bra @prox
@ok:    inc NGRAV
        bne @prox
        inc NGRAV+1
        bra @prox
@igual: inc NIGUAL
        bne @prox
        inc NIGUAL+1
@prox:  jsr avanca
        bne @g
        lda EE_WEON             ; leitura = trava
; ---------- conferencia ----------
        jsr inicio_ptr
@v:     lda (PTR)
        cmp (SRC)
        beq @vok
        inc NDIF
        bne @vok
        inc NDIF+1
@vok:   jsr avanca
        bne @v
        lda EE_BANK0            ; volta ao banco 0 (tambem trava)
        lda $CFFF
; ---------- resumo ----------
        jsr msg
        .byte "GRAVADOS ",0
        lda NGRAV+1
        ldx NGRAV
        jsr hex16
        jsr msg
        .byte " IGUAIS ",0
        lda NIGUAL+1
        ldx NIGUAL
        jsr hex16
        jsr msg
        .byte " FALHAS ",0
        lda NERRO+1
        ldx NERRO
        jsr hex16
        jsr msg
        .byte " DIFERENCAS ",0
        lda NDIF+1
        ldx NDIF
        jsr hex16
        jsr msg
        .byte " SOMA ",0
        lda SOMA+1
        ldx SOMA
        jsr hex16
        jsr CROUT
        cli
        rts

cancela:
        lda $CFFF
        lda EE_BANK0
        jsr msg
        .byte "CANCELADO",0
        jsr CROUT
        cli
        rts

; ---------- rotinas ----------
inicio_ptr:
        lda #$00
        sta PTR
        lda #$C7
        sta PTR+1
        lda #<BUF
        sta SRC
        lda #>BUF
        sta SRC+1
        rts
avanca:                         ; Z=0 enquanto PTR < fim
        inc SRC
        bne @a1
        inc SRC+1
@a1:    inc PTR
        bne @a2
        inc PTR+1
@a2:    lda BANCO               ; v2: bit 7 de BANCO = gravar tudo ate $CEFF
        bmi @tudo
        lda PTR+1               ; normal: para em $CE80 e preserva a tabela de montagem
        cmp #$CE                ; (banco 4, $CE80-$CEE0) e os nomes (banco 0, $CEC0-$CEF0)
        bne @a3
        lda PTR
        cmp #$80
@a3:    rts
@tudo:  lda PTR+1
        cmp #$CF
        rts
envia:  pha
@e:     lda SSCST
        and #$10
        beq @e
        pla
        sta SSCDAT
        rts
recebe: lda KBD
        bpl @r1
        cmp #$9B                ; ESC
        bne @r1
        bit KBDSTRB
        sec
        rts
@r1:    lda SSCST
        and #$08
        beq recebe
        lda SSCDAT
        clc
        rts
espera: ldx #0
        ldy #2
@w:     dex
        bne @w
        dey
        bne @w
        rts
hex16:  jsr PRBYTE
        txa
        jmp PRBYTE
msg:    pla
        sta SRC
        pla
        sta SRC+1
@m:     inc SRC
        bne @m2
        inc SRC+1
@m2:    lda (SRC)
        beq @d
        ora #$80
        jsr COUT
        bra @m
@d:     lda SRC+1
        pha
        lda SRC
        pha
        rts
