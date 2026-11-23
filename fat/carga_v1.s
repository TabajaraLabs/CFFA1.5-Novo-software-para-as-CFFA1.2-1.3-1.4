; carga_v1.s - carregador binario pela Super Serial (slot 1), mora na pagina 3
; Protocolo do #sendbin da ponte: antes de cada bloco de 256 bytes o Apple manda ACK ($06).
; Uso no monitor:  302:PP NN   (PP = pagina inicial, NN = numero de blocos de 256)   depois 300G
; Do BASIC.SYSTEM:  BRUN CARGA  (usa o padrao: pagina $60, 8 blocos = 2 KB em $6000-$67FF)
; No fim imprime "S=xxxx" (soma simples de 16 bits de todos os bytes) para conferir.
; Montar: ca65 --cpu 65C02 carga_v1.s && ld65 -t none -S $300 carga_v1.o -o carga_v1.bin
        .setcpu "65C02"
        .org $0300
SDATA   = $C098
SSTAT   = $C099
COUT    = $FDED
CROUT   = $FD8E
PRBYTE  = $FDDA
P       = $FA

        bra start               ; $0300: entrada
PAGE:   .byte $60               ; $0302: pagina inicial
NBLK:   .byte $08               ; $0303: blocos de 256 bytes
start:  lda PAGE
        sta P+1
        stz P
        stz SUM
        stz SUM+1
        ldx NBLK
@b:     lda SSTAT               ; transmissor vazio?
        and #$10
        beq @b
        lda #$06                ; ACK: pode mandar o bloco
        sta SDATA
        ldy #0
@r:     lda SSTAT               ; byte recebido?
        and #$08
        beq @r
        lda SDATA
        sta (P),y
        clc
        adc SUM
        sta SUM
        bcc @n
        inc SUM+1
@n:     iny
        bne @r
        inc P+1
        dex
        bne @b
        lda #'S'|$80
        jsr COUT
        lda #'='|$80
        jsr COUT
        lda SUM+1
        jsr PRBYTE
        lda SUM
        jsr PRBYTE
        jmp CROUT
SUM:    .word 0
