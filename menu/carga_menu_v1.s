; carga_menu_v1.s - estagio 1 do banco 0 da CFFA v1.2 (firmware 1.4): carrega CFFAMENU.BIN do cartao FAT
; Tabajara Labs, 2026-11-20. O trampolim do 1.4 copia o banco 0 ($C800-$CEFF) para $2000-$26FF e chama $2003.
; Procura CFFAMENU.BIN na raiz (FAT16/FAT32), carrega em $4000 (ate 16 KB) seguindo a cadeia de clusters,
; confere "CFM1" em $4000 e chama $4004 (X = $70). Sem o arquivo, mostra um aviso e segue o boot.
; O fim do banco ($CEC0-$CEEC) guarda os nomes das imagens montadas (gravados pelo CFFAMENU).
; Montar: ca65 --cpu 65C02 carga_menu_v1.s && ld65 -t none -S $2000 carga_menu_v1.o -o carga_menu_v1.bin (1792 bytes)
        .setcpu "65C02"
        .org $2000
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
WUNL    = IOB+3                 ; CPLD v1.6: escrever = destrava gravacao; ler = trava
BK0     = IOB+4                 ; qualquer acesso: banco 0
BK4     = IOB+5                 ; qualquer acesso: banco 4
DRVRST  = $0478 + SLOT          ; DriveResetDone do driver (zerar = refazer FatInit)

COUT    = $FDED
CROUT   = $FD8E
PRBYTE  = $FDDA
HOME    = $FC58
RDKEY   = $FD0C
WAIT    = $FCA8
KBD     = $C000
KBDSTRB = $C010

ROMCFG  = $CE80                 ; tabela do driver no banco 4 ($CE80-$CEE0, $CEE0 = 'C')
CFGLEN  = $61
ROMNAM  = $CEC0                 ; nomes no banco 0 ($CEC0-$CEEC, $CEEC = 'N')
NAMLEN  = 45

PTR     = $06
ENT     = $08
CP      = $EB                   ; ponteiro de trabalho (tabela nova)
MP      = $FA
TMP     = $FC
CNT     = $FD
LP      = $FE                   ; ponteiro para a entrada da lista de imagens

SBUF    = $2800
FATB    = $2A00
V       = $2C00
LST     = $8D00                 ; 16 imagens x 24 bytes: nome 11, bytes 20-21 e 26-31 da entrada (8), LBA do dir (4), indice (1)
NEWCFG  = $8E80                 ; tabela nova (97 bytes)
NEWNAM  = $8F00                 ; nomes novos (45 bytes)
OLD     = $8F40                 ; copia de uma entrada da tabela (24 bytes)

vLBA    = 0
vPST    = 4
vFATST  = 8
vROOTST = 12
vDATAST = 16
vROOTCL = 20
vFATSZ  = 24
vT1     = 28
vCLUS   = 32
vFCACHE = 36
vDIRL   = 40
vFCL    = 44
vFSZ    = 48
vNCL    = 52
vT2     = 56
vNXT    = 60
vDCL    = 64
SPCV    = V+68
SPSH    = V+69
NFAT    = V+70
FTYP    = V+71
RSECS   = V+72
SLEFT   = V+74
CVAL    = V+75
NIMG    = V+76
FRAG    = V+77
FOFS    = V+78
SAVSP   = V+80
ESZ     = V+81
FORCE   = V+82
DRV     = V+83
SEL     = V+84
BANKS   = V+85


DSTPG   = V+86
REM     = V+87                  ; setores que faltam (16 bits)

        .byte "CFU"
        cpx #SLOT*16            ; $2003
        beq @ok
        rts
@ok:    tsx
        stx SAVSP
        stz CVAL
        jsr fsinit
        bcs @out                ; (o driver ja disse que e FAT; nao deveria acontecer)
        jsr scan
        lda NIMG
        bne @load
        jsr msg
        .byte "CFFA: CFFAMENU.BIN NAO ENCONTRADO",0
        jsr CROUT
        ldx #8
@w:     lda #$FF
        jsr WAIT
        dex
        bne @w
@out:   rts
@load:  jsr load
        ldx #3
@sig:   lda $4000,x
        cmp sig,x
        bne @bad
        dex
        bpl @sig
        ldx #SLOT*16
        jmp $4004
@bad:   jsr msg
        .byte "CFFA: CFFAMENU.BIN INVALIDO",0
        jmp CROUT
sig:    .byte "CFM1"
fname:  .byte "CFFAMENUBIN"

; entry: confere se a entrada (ENT) e CFFAMENU.BIN; se for, guarda cluster e tamanho e encerra a busca
entry:  ldy #11
        lda (ENT),y
        and #$18                ; pasta / rotulo (o nome longo tem atributo $0F: tambem cai aqui)
        bne @x
        ldy #10
@c:     lda (ENT),y
        cmp fname,y
        bne @x
        dey
        bpl @c
        ldy #$1A
        lda (ENT),y
        sta V+vFCL
        iny
        lda (ENT),y
        sta V+vFCL+1
        stz V+vFCL+2
        stz V+vFCL+3
        lda FTYP
        beq @s
        ldy #$14
        lda (ENT),y
        sta V+vFCL+2
        iny
        lda (ENT),y
        sta V+vFCL+3
@s:     ldy #$1F                ; setores = (tamanho + 511) / 512, no maximo 32 (16 KB)
        lda (ENT),y
        dey
        ora (ENT),y
        bne @max                ; >= 64 KB
        dey
        lda (ENT),y
        lsr
        sta REM
        bcs @inc                ; sobra no bit 8
        dey
        lda (ENT),y
        beq @ok2
@inc:   inc REM
@ok2:   lda REM
        cmp #33
        bcc @fim
@max:   lda #32
        sta REM
@fim:   inc NIMG
        pla                     ; descarta o retorno para o dirsec: o RTS abaixo sai do dirsec
        pla                     ; com C=1 e o scan termina
        sec
        rts
@x:     rts

; load: le REM setores da cadeia de clusters que comeca em vFCL para $4000...
load:   lda #$40
        sta DSTPG
        ldx #vCLUS
        ldy #vFCL
        jsr cpy32
@cl:    jsr c2l
        lda SPCV
        sta SLEFT
@sec:   lda DSTPG
        jsr rdsec
        bcc @r
        jmp ioerr
@r:     inc DSTPG
        inc DSTPG
        dec REM
        beq @done
        ldx #vLBA
        jsr inc32
        dec SLEFT
        bne @sec
        jsr fatnext
        bcs @done
        ldx #vCLUS
        ldy #vNXT
        jsr cpy32
        bra @cl
@done:  rts
; ============================================================================
; fsinit: le MBR/VBR e o BPB. C=1 se nao for FAT16/FAT32
fsinit: ldx #vLBA
        jsr zero32
        ldx #vPST
        jsr zero32
        jsr rdsec_s
        bcs @no
        lda SBUF+$1FE
        cmp #$55
        bne @no
        lda SBUF+$1FF
        cmp #$AA
        bne @no
        jsr isvbr
        bcc @parse
        lda SBUF+$1C2
        ldx #5
@tp:    cmp fattypes,x
        beq @ok
        dex
        bpl @tp
@no:    sec
        rts
@ok:    ldx #3
@cp:    lda SBUF+$1C6,x
        sta V+vPST,x
        sta V+vLBA,x
        dex
        bpl @cp
        jsr rdsec_s
        bcs @no
        jsr isvbr
        bcs @no
@parse: lda SBUF+$0D
        sta SPCV
        ldx #0
@sh:    lsr
        bcs @shd
        inx
        cpx #8
        bne @sh
@shd:   stx SPSH
        lda SBUF+$10
        sta NFAT
        ldx #vT1
        jsr zero32
        lda SBUF+$0E
        sta V+vT1
        lda SBUF+$0F
        sta V+vT1+1
        ldx #vFATST
        ldy #vPST
        jsr cpy32
        ldy #vT1
        jsr add32
        ldx #vFATSZ
        jsr zero32
        lda SBUF+$16
        ora SBUF+$17
        beq @f32
        lda SBUF+$3A            ; "FAT12" recusada
        cmp #'2'
        beq @no
        stz FTYP
        lda #2
        sta ESZ
        lda SBUF+$16
        sta V+vFATSZ
        lda SBUF+$17
        sta V+vFATSZ+1
        bra @fz
@f32:   lda #1
        sta FTYP
        lda #4
        sta ESZ
        ldx #3
@c32:   lda SBUF+$24,x
        sta V+vFATSZ,x
        lda SBUF+$2C,x
        sta V+vROOTCL,x
        dex
        bpl @c32
@fz:    ldx #vROOTST
        ldy #vFATST
        jsr cpy32
        lda NFAT
        sta CNT
@nf:    ldy #vFATSZ
        jsr add32
        dec CNT
        bne @nf
        ldx #vT1
        jsr zero32
        lda SBUF+$11
        sta V+vT1
        lda SBUF+$12
        sta V+vT1+1
        ldy #4
@d16:   lsr V+vT1+1
        ror V+vT1
        dey
        bne @d16
        lda V+vT1
        sta RSECS
        lda V+vT1+1
        sta RSECS+1
        ldx #vDATAST
        ldy #vROOTST
        jsr cpy32
        ldy #vT1
        jsr add32
        clc
        rts
fattypes: .byte $04,$06,$0E,$0B,$0C,$01

isvbr:  lda SBUF
        cmp #$EB
        beq @j
        cmp #$E9
        bne @no
@j:     lda SBUF+$0B
        bne @no
        lda SBUF+$0C
        cmp #2
        bne @no
        lda SBUF+$10
        beq @no
        cmp #3
        bcs @no
        clc
        rts
@no:    sec
        rts

; ============================================================================
; scan: percorre o diretorio raiz e guarda as imagens em LST (ate 16)
scan:   stz NIMG             ; (NIMG = 1 quando achar o arquivo)
        lda FTYP
        bne @d32
        ldx #vDIRL
        ldy #vROOTST
        jsr cpy32
@ds:    lda RSECS
        ora RSECS+1
        beq @end
        jsr dirsec
        bcs @end
        ldx #vDIRL
        jsr inc32
        lda RSECS
        bne @dd
        dec RSECS+1
@dd:    dec RSECS
        bra @ds
@d32:   ldx #vDCL
        ldy #vROOTCL
        jsr cpy32
@dc:    ldx #vCLUS
        ldy #vDCL
        jsr cpy32
        jsr c2l
        ldx #vDIRL
        ldy #vLBA
        jsr cpy32
        lda SPCV
        sta SLEFT
@dsc:   jsr dirsec
        bcs @end
        ldx #vDIRL
        jsr inc32
        dec SLEFT
        bne @dsc
        ldx #vCLUS
        ldy #vDCL
        jsr cpy32
        jsr fatnext
        bcs @end
        ldx #vDCL
        ldy #vNXT
        jsr cpy32
        bra @dc
@end:   rts

dirsec: ldx #vLBA
        ldy #vDIRL
        jsr cpy32
        jsr rdsec_s
        bcc @ok
        jmp ioerr
@ok:    lda #<SBUF
        sta ENT
        lda #>SBUF
        sta ENT+1
@e:     lda (ENT)
        bne @nz
        sec
        rts
@nz:    jsr entry
        clc
        lda ENT
        adc #32
        sta ENT
        bcc @e
        inc ENT+1
        lda ENT+1
        cmp #>(SBUF+512)
        bne @e
        clc
        rts


; c2l: vLBA = DATAST + (vCLUS - 2) << SPSH
c2l:    ldx #vT1
        ldy #vCLUS
        jsr cpy32
        sec                     ; T1 = CLUS - 2 (sem CPY no meio: preserva o carry)
        lda V+vT1
        sbc #2
        sta V+vT1
        lda V+vT1+1
        sbc #0
        sta V+vT1+1
        lda V+vT1+2
        sbc #0
        sta V+vT1+2
        lda V+vT1+3
        sbc #0
        sta V+vT1+3
        ldy SPSH
        beq @a
@s:     jsr shl32
        dey
        bne @s
@a:     ldx #vLBA
        ldy #vDATAST
        jsr cpy32
        ldy #vT1
        jmp add32

; fatnext: vNXT = FAT[vCLUS]; C=1 se fim de cadeia (EOC), cluster livre ou invalido.
; Em erro de leitura: sai pelo ioerr.
fatnext:
        ; T2 = indice do setor na FAT; PTR = FATB + deslocamento
        ldx #vT2
        ldy #vCLUS
        jsr cpy32
        lda FTYP
        bne @f32
        ; FAT16: setor = CLUS>>8, desloc = (CLUS & $FF)*2
        lda V+vT2+1
        sta V+vT2
        lda V+vT2+2
        sta V+vT2+1
        lda V+vT2+3
        sta V+vT2+2
        stz V+vT2+3
        lda V+vCLUS
        asl
        sta FOFS
        lda #0
        rol
        sta FOFS+1
        bra @rd
@f32:   ; FAT32: setor = CLUS>>7, desloc = (CLUS & $7F)*4
        lda V+vCLUS
        and #$7F
        asl
        asl
        sta FOFS
        lda #0
        rol
        sta FOFS+1
        ldy #7
@sr:    lsr V+vT2+3
        ror V+vT2+2
        ror V+vT2+1
        ror V+vT2
        dey
        bne @sr
@rd:    ldx #vLBA
        ldy #vFATST
        jsr cpy32
        ldy #vT2
        jsr add32
        lda CVAL
        beq @load
        ldx #vLBA
        ldy #vFCACHE
        jsr cmp32
        beq @have
@load:  lda #>FATB
        jsr rdsec
        bcc @ld
        jmp ioerr
@ld:    ldx #vFCACHE
        ldy #vLBA
        jsr cpy32
        lda #1
        sta CVAL
@have:  lda FOFS
        sta PTR
        lda #>FATB
        clc
        adc FOFS+1
        sta PTR+1
        ldx #vNXT
        jsr zero32
        ldy #0
        lda (PTR),y
        sta V+vNXT
        iny
        lda (PTR),y
        sta V+vNXT+1
        lda FTYP
        bne @e32
        ; FAT16: >= $FFF8 fim; < 2 invalido
        lda V+vNXT+1
        cmp #$FF
        bne @lo16
        lda V+vNXT
        cmp #$F8
        bcs @eoc
@lo16:  lda V+vNXT+1
        bne @ok
        lda V+vNXT
        cmp #2
        bcc @eoc
@ok:    clc
        rts
@e32:   iny
        lda (PTR),y
        sta V+vNXT+2
        iny
        lda (PTR),y
        and #$0F
        sta V+vNXT+3
        cmp #$0F
        bne @lo32
        lda V+vNXT+2
        and V+vNXT+1
        cmp #$FF
        bne @lo32
        lda V+vNXT
        cmp #$F8
        bcs @eoc
@lo32:  lda V+vNXT+3
        ora V+vNXT+2
        ora V+vNXT+1
        bne @ok
        lda V+vNXT
        cmp #2
        bcs @ok
@eoc:   sec
        rts

; ============================================================================
; aritmetica de 32 bits sobre V (X = destino, Y = origem; deslocamentos)
zero32: stz V,x
        stz V+1,x
        stz V+2,x
        stz V+3,x
        rts
cpy32:  lda V,y
        sta V,x
        lda V+1,y
        sta V+1,x
        lda V+2,y
        sta V+2,x
        lda V+3,y
        sta V+3,x
        rts
add32:  clc
        lda V,x
        adc V,y
        sta V,x
        lda V+1,x
        adc V+1,y
        sta V+1,x
        lda V+2,x
        adc V+2,y
        sta V+2,x
        lda V+3,x
        adc V+3,y
        sta V+3,x
        rts
inc32:  inc V,x
        bne @r
        inc V+1,x
        bne @r
        inc V+2,x
        bne @r
        inc V+3,x
@r:     rts
dec32:  lda V,x
        bne @a
        lda V+1,x
        bne @b
        lda V+2,x
        bne @c
        dec V+3,x
@c:     dec V+2,x
@b:     dec V+1,x
@a:     dec V,x
        rts
shl32:  asl V,x
        rol V+1,x
        rol V+2,x
        rol V+3,x
        rts
cmp32:  lda V,x                 ; Z=1 se iguais
        cmp V,y
        bne @r
        lda V+1,x
        cmp V+1,y
        bne @r
        lda V+2,x
        cmp V+2,y
        bne @r
        lda V+3,x
        cmp V+3,y
@r:     rts
pr32:   lda V+3,x
        jsr PRBYTE
        lda V+2,x
        jsr PRBYTE
        lda V+1,x
        jsr PRBYTE
        lda V,x
        jmp PRBYTE


; leitura de setor (LBA 28 bits em vLBA) para o buffer de pagina A (512 bytes). C=1 = erro
rdsec_s: lda #>SBUF
rdsec:  sta PTR+1
        stz PTR
        jsr waitrdy
        bcs @r
        lda #1
        sta SECCNT
        lda V+vLBA
        sta SECT
        lda V+vLBA+1
        sta CYL
        lda V+vLBA+2
        sta CYLH
        lda V+vLBA+3
        and #$0F
        ora #$E0
        sta HEAD
        stz DATAH
        lda #$20
        sta CMD
        jsr waitrdy
        bcs @r
        lda STATUS
        and #$09
        cmp #$08
        bne @e
        ldx #2
        ldy #0
@l:     lda DATAL
        sta (PTR),y
        iny
        lda DATAH
        sta (PTR),y
        iny
        bne @l
        inc PTR+1
        dex
        bne @l
        clc
@r:     rts
@e:     sec
        rts

; espera BSY=0 (maximo ~2 s)
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


pch:    and #$7F
        cmp #$20
        bcs @p
        lda #'.'
@p:     ora #$80
        jmp COUT

; imprime string inline (terminada em 0) logo apos o JSR; preserva X e Y
msg:    pla
        sta MP
        pla
        sta MP+1
@m:     inc MP
        bne @m2
        inc MP+1
@m2:    lda (MP)
        beq @d
        ora #$80
        jsr COUT
        bra @m
@d:     lda MP+1
        pha
        lda MP
        pha
        rts


ioerr:  ldx SAVSP
        txs
        jsr msg
        .byte "CFFA: ERRO DE LEITURA",0
        jmp CROUT

        .res $26C0-*, $FF       ; $CEC0 no banco 0: nomes (gravados pelo CFFAMENU)
        .res 44, ' '
        .byte 'N'
        .res $2700-*, $FF
