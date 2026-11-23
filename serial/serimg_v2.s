; serimg_v2.s - transfere imagens de disco entre o PC e um drive da CFFA pela Super Serial (slot 1)
; Tabajara Labs, 2026-11-20. Roda em $6000 (a partir do monitor). Usa o driver da propria CFFA ($C70A),
; entao vale para imagem montada em cartao FAT (firmware 1.4/1.5) e para particao de cartao cru.
;   $6003 OP     0 = PC -> Apple (grava no drive)   1 = Apple -> PC (le do drive, backup)
;   $6004 UNIT   $70 = drive 1, $F0 = drive 2 (drives 3/4: unidade do slot espelhado, ex. $40/$C0)
;   $6005 NBLK   numero de blocos de 512 bytes (2 bytes); 0 = o tamanho do drive (STATUS do driver)
;   $6007 BLK0   primeiro bloco (2 bytes)
;   $6009 RAPIDO 1 = troca para 115200 durante a transferencia (pede a ponte com ESC 01 'B' '4')
;   $600A CONF   1 = depois de gravar, rele tudo e confere a soma
; Protocolo: gravacao: o Apple manda ACK ($06) antes de cada bloco de 512 (#sendbin ARQ 512 na ponte).
;            backup: o Apple espera um byte qualquer da ponte (#recvbin), manda 2 bytes com o numero de blocos
;            e depois os blocos em sequencia.
; No fim imprime: BLOCOS nnnn SOMA ssss [CONFERE xxxx] e OK ou o erro.
; v2: CLD na entrada. O G do monitor restaura P de $48, e o bloco de boot do ProDOS deixa $FF ali:
;     com D=1 as somas de numero de bloco viravam BCD e o driver lia/gravava o bloco errado.
; Montar: ca65 --cpu 65C02 serimg_v2.s && ld65 -t none -S $6000 serimg_v2.o -o serimg_v2.bin
        .setcpu "65C02"
        .org $6000
SDATA   = $C098
SSTAT   = $C099
SCTL    = $C09B
P8      = $C70A
COUT    = $FDED
CROUT   = $FD8E
PRBYTE  = $FDDA
KBD     = $C000
KBDSTRB = $C010
WAIT    = $FCA8
BUF     = $7000
P       = $FA                   ; ponteiro do msg

        jmp start
OP:     .byte 0
UNIT:   .byte $70
NBLK:   .word 280
BLK0:   .word 0
RAPIDO: .byte 1
CONF:   .byte 1
SUM:    .word 0
VSUM:   .word 0
CUR:    .word 0
CNT:    .word 0
SAVCTL: .byte 0
ERR:    .byte 0                 ; 0 = ok, 1 = tempo esgotado/ESC, 2 = erro do driver (codigo em DERR)
DERR:   .byte 0
TMO:    .byte 0
TMO2:   .byte 0

start:  sei
        cld                     ; v2: modo binario (P vem de $48 no G do monitor)
        stz SUM
        stz SUM+1
        stz VSUM
        stz VSUM+1
        stz ERR
        lda SSTAT               ; limpa a recepcao
        lda SDATA
        lda SCTL
        sta SAVCTL
        lda RAPIDO
        beq @go
        ldx #'4'                ; pede 115200 para a ponte (ainda na velocidade antiga)
        jsr baudreq
        jsr pausa
        lda #$10                ; 6551: relogio externo /16 = 1,8432 MHz / 16 = 115200, 8N1
        sta SCTL
        jsr pausa
        jsr pausa
        ldx #'K'                ; confirma na velocidade nova
        jsr baudreq
@go:    lda NBLK                ; 0 blocos = o tamanho do drive (STATUS)
        ora NBLK+1
        bne @g2
        lda #0
        jsr drv
        bcc @st
        sta DERR
        lda #2
        sta ERR
        jmp fim
@st:    stx NBLK
        sty NBLK+1
@g2:    lda BLK0
        sta CUR
        lda BLK0+1
        sta CUR+1
        lda NBLK
        sta CNT
        lda NBLK+1
        sta CNT+1
        lda OP
        beq recv
        jmp send

; ---------------- PC -> Apple: recebe e grava ----------------
recv:   lda CNT
        ora CNT+1
        beq @conf
        lda #$06                ; ACK: pode mandar o proximo bloco
        jsr tx
        jsr rxblk
        bcs @to
        jsr sumblk
        lda #2                  ; WRITE
        jsr drv
        bcs @de
        jsr nextb
        bra recv
@to:    lda #1
        sta ERR
        jmp fim
@de:    sta DERR
        lda #2
        sta ERR
        jmp fim
@conf:  lda CONF                ; rele e confere
        beq @f
        lda BLK0
        sta CUR
        lda BLK0+1
        sta CUR+1
        lda NBLK
        sta CNT
        lda NBLK+1
        sta CNT+1
@v:     lda CNT
        ora CNT+1
        beq @f
        lda #1
        jsr drv
        bcs @de
        jsr vsumblk
        jsr nextb
        bra @v
@f:     jmp fim

; ---------------- Apple -> PC: le e envia ----------------
send:   jsr rxlong              ; espera o "pode mandar" da ponte
        bcc @h
        lda #1
        sta ERR
        jmp fim
@h:     lda NBLK                ; cabecalho: numero de blocos (2 bytes)
        jsr tx
        lda NBLK+1
        jsr tx
@s:     lda CNT
        ora CNT+1
        beq @f
        lda #1                  ; READ
        jsr drv
        bcs @de
        jsr sumblk
        jsr txblk
        jsr nextb
        bra @s
@de:    sta DERR
        lda #2
        sta ERR
@f:     jmp fim

; ---------------- fim: volta a velocidade e imprime o resumo ----------------
fim:    lda RAPIDO
        beq @p
        jsr txfim
        ldx #'1'                ; ponte volta para 19200
        jsr baudreq
        jsr txfim
        jsr pausa
        lda SAVCTL
        sta SCTL
        jsr pausa
        jsr pausa
        ldx #'K'
        jsr baudreq
        jsr pausa
@p:     cli
        jsr msg
        .byte "BLOCOS ",0
        lda NBLK+1
        jsr PRBYTE
        lda NBLK
        jsr PRBYTE
        jsr msg
        .byte " SOMA ",0
        lda SUM+1
        jsr PRBYTE
        lda SUM
        jsr PRBYTE
        lda OP
        bne @r
        lda CONF
        beq @r
        jsr msg
        .byte " CONFERE ",0
        lda VSUM+1
        jsr PRBYTE
        lda VSUM
        jsr PRBYTE
@r:     lda ERR
        bne @e
        lda OP
        bne @ok
        lda CONF
        beq @ok
        lda VSUM
        cmp SUM
        bne @vd
        lda VSUM+1
        cmp SUM+1
        bne @vd
@ok:    jsr msg
        .byte " OK",0
        jmp CROUT
@vd:    jsr msg
        .byte " DIFERENTE NA RELEITURA!",0
        jmp CROUT
@e:     cmp #1
        bne @d
        jsr msg
        .byte " PARADO (TEMPO ESGOTADO OU ESC) NO BLOCO ",0
        bra @blk
@d:     jsr msg
        .byte " ERRO DO DRIVER $",0
        lda DERR
        jsr PRBYTE
        jsr msg
        .byte " NO BLOCO ",0
@blk:   lda CUR+1
        jsr PRBYTE
        lda CUR
        jsr PRBYTE
        jmp CROUT

; ---------------- rotinas ----------------
; drv: chama o driver da CFFA: A = comando (1 le, 2 grava) no bloco CUR, buffer BUF
drv:    sta $42
        lda UNIT
        sta $43
        lda #<BUF
        sta $44
        lda #>BUF
        sta $45
        lda CUR
        sta $46
        lda CUR+1
        sta $47
        jmp P8

nextb:  inc CUR
        bne @1
        inc CUR+1
@1:     lda CNT
        bne @2
        dec CNT+1
@2:     dec CNT
        rts

; rxblk: recebe 512 bytes em BUF. C=1 se o tempo acabar (~0,8 s sem dados) ou ESC.
; O primeiro byte pode demorar ate ~10 s. A 115200 sobram ~89 ciclos por byte: o laco usa ~25.
rxblk:  jsr rxlong
        bcs @x
        sta BUF
        ldy #1
@a:     ldx #0
        stz TMO
@w1:    lda SSTAT
        and #$08
        bne @g1
        dex
        bne @w1
        dec TMO
        bne @w1
        sec
        rts
@g1:    lda SDATA
        sta BUF,y
        iny
        bne @a
@b:     ldx #0
        stz TMO
@w2:    lda SSTAT
        and #$08
        bne @g2
        dex
        bne @w2
        dec TMO
        bne @w2
        sec
        rts
@g2:    lda SDATA
        sta BUF+256,y
        iny
        bne @b
        clc
@x:     rts

; rxlong: espera um byte por ate ~10 s (ESC no teclado cancela). C=1 se nao veio.
rxlong: lda #40
        sta TMO2
@o:     ldx #0
        stz TMO
@w:     lda SSTAT
        and #$08
        bne @g
        dex
        bne @w
        lda KBD
        cmp #$9B
        beq @esc
        dec TMO
        bne @w
        dec TMO2
        bne @o
        sec
        rts
@esc:   sta KBDSTRB
        sec
        rts
@g:     lda SDATA
        clc
        rts

tx:     pha
@w:     lda SSTAT
        and #$10
        beq @w
        pla
        sta SDATA
        rts

; txfim: espera o ultimo byte sair
txfim:  lda SSTAT
        and #$10
        beq txfim
        lda #10
        jmp WAIT

txblk:  ldy #0
@a:     lda BUF,y
        jsr tx
        iny
        bne @a
@b:     lda BUF+256,y
        jsr tx
        iny
        bne @b
        rts

; baudreq: manda ESC 01 'B' X para a ponte
baudreq: lda #$1B
        jsr tx
        lda #$01
        jsr tx
        lda #'B'
        jsr tx
        txa
        jmp tx

; pausa de ~170 ms
pausa:  lda #$FF
        jmp WAIT

; sumblk / vsumblk: soma de 16 bits dos 512 bytes de BUF em SUM / VSUM
sumblk: ldx #0
        bra sb
vsumblk: ldx #2
sb:     ldy #0
@a:     lda BUF,y
        jsr @add
        lda BUF+256,y
        jsr @add
        iny
        bne @a
        rts
@add:   clc
        adc SUM,x
        sta SUM,x
        bcc @n
        inc SUM+1,x
@n:     rts

msg:    pla
        sta P
        pla
        sta P+1
@m:     inc P
        bne @m2
        inc P+1
@m2:    lda (P)
        beq @d
        ora #$80
        jsr COUT
        bra @m
@d:     lda P+1
        pha
        lda P
        pha
        rts
