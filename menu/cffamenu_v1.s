; cffamenu_v1.s - menu da CFFA v1.2 (firmware 1.4) para imagens ProDOS em cartao FAT16/FAT32
; Tabajara Labs, 2026-11-20. Arquivo CFFAMENU.BIN na raiz do cartao FAT; o carregador do banco 0
; (estagio 1) carrega em $4000 e chama $4004. Tambem roda do monitor (carregado pela serial): 4007G.
;   $4000: "CFM1" (assinatura conferida pelo carregador)
;   $4004: entrada do boot   (X = $n0; so funciona no slot 7). Menu se houver tecla ou nada montado.
;   $4007: entrada de teste  (menu sempre)
; Grava a tabela de montagem no banco 4 ($CE80-$CEE0) e os nomes no banco 0 ($CEC0-$CEEC).
; Montar: ca65 --cpu 65C02 cffamenu_v1.s && ld65 -t none -S $4000 cffamenu_v1.o -o CFFAMENU.BIN
        .setcpu "65C02"
        .org $4000

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

SBUF    = $8800                 ; (o carregador do banco 0 fica em $2000-$2FFF: nao mexer)
FATB    = $8A00
V       = $8C00
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

; ============================================================================
        .byte "CFM1"
        jmp boot                ; $4004
        jmp menuent             ; $4007

boot:   cpx #SLOT*16
        beq @ok
        rts                     ; outro slot: o utilitario so conhece o slot 7
@ok:    stz FORCE
        bra main
menuent: lda #1
        sta FORCE
main:   tsx
        stx SAVSP
        jsr romon
        stz CVAL
        jsr fsinit
        bcc @fat
        jsr msg
        .byte "CFFA: CARTAO NAO E FAT16/FAT32",0
        jmp CROUT
@fat:   jsr scan
        jsr loadcfg
        jsr resolve
        lda FORCE
        bne @menu
        ldx #0                  ; algum drive montado?
@any:   lda NEWCFG,x
        bmi @some
        txa
        clc
        adc #24
        tax
        cpx #96
        bne @any
        bra @menu               ; nada montado: menu
@some:  jsr HOME
        jsr msg
        .byte "CFFA 1.4 - QUALQUER TECLA = MENU",0
        jsr CROUT
        jsr showmnt
        ldx #10                 ; ~1,7 s esperando uma tecla
@w:     lda KBD
        bmi @key
        lda #$FF
        jsr WAIT
        dex
        bne @w
        bra @save
@key:   sta KBDSTRB
@menu:  jsr menu
        bcs @exit               ; ESC: sai sem gravar
@save:  jsr save
@exit:  jsr romon
        rts

; religa a ROM $C800 desta placa e seleciona o banco 4
romon:  bit $CFFF
        lda $C000+SLOT*256      ; $C700: liga a ROM $C800 do slot 7
        lda BK4
        rts

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
scan:   stz NIMG
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

entry:  lda (ENT)
        cmp #$E5
        beq @x
        ldy #11
        lda (ENT),y
        cmp #$0F
        beq @x
        and #$18
        bne @x
        ldx #0
@ext:   ldy #8
        lda (ENT),y
        cmp exts,x
        bne @nx
        iny
        lda (ENT),y
        cmp exts+1,x
        bne @nx
        iny
        lda (ENT),y
        cmp exts+2,x
        beq image
@nx:    inx
        inx
        inx
        cpx #9
        bne @ext
@x:     rts
exts:   .byte "PO ","HDV","IMG"

image:  ldy #$1A                ; cluster 0 = vazio: ignora
        lda (ENT),y
        iny
        ora (ENT),y
        ldy #$14
        ora (ENT),y
        iny
        ora (ENT),y
        beq @x
        lda NIMG
        cmp #16
        bcs @x
        jsr lstptr
        ldy #10
@n:     lda (ENT),y
        sta (LP),y
        dey
        bpl @n
        ldx #7                  ; bytes 20-21 e 26-31 da entrada -> LP+11..18
@r:     ldy rawofs,x
        lda (ENT),y
        pha
        txa
        clc
        adc #11
        tay
        pla
        sta (LP),y
        dex
        bpl @r
        ldx #0                  ; LBA do setor de diretorio -> LP+19..22
        ldy #19
@l:     lda V+vDIRL,x
        sta (LP),y
        iny
        inx
        cpx #4
        bne @l
        lda ENT+1               ; indice = (ENT-SBUF)/32
        sec
        sbc #>SBUF
        lsr
        lda ENT
        ror
        lsr
        lsr
        lsr
        lsr
        sta (LP),y              ; LP+23
        inc NIMG
@x:     rts
rawofs: .byte 20,21,26,27,28,29,30,31

; LP = LST + A*24
lstptr: sta TMP
        asl
        adc TMP                 ; A*3 (A<16: sem carry)
        asl
        asl
        asl                     ; A*24 (<384: carry vai para a pagina)
        sta LP
        lda #>LST
        adc #0
        sta LP+1
        rts

; vFCL e vFSZ a partir da entrada da lista (LP)
getfcl: ldy #13
        lda (LP),y
        sta V+vFCL
        iny
        lda (LP),y
        sta V+vFCL+1
        stz V+vFCL+2
        stz V+vFCL+3
        lda FTYP
        beq @s
        ldy #11
        lda (LP),y
        sta V+vFCL+2
        iny
        lda (LP),y
        sta V+vFCL+3
@s:     ldx #3
        ldy #18
@z:     lda (LP),y
        sta V+vFSZ,x
        dey
        dex
        bpl @z
        rts

; ============================================================================
; contig: confere se a imagem (vFCL) e contigua. FRAG = 1 se nao. ESC interrompe (FRAG = 1)
contig: stz FRAG
        ldx #vCLUS
        ldy #vFCL
        jsr cpy32
@slow:  lda KBD
        cmp #$9B
        bne @s1
        sta KBDSTRB
        bra @bad
@s1:    jsr fatnext
        bcs @end
        ldx #vT2
        ldy #vCLUS
        jsr cpy32
        jsr inc32
        ldy #vNXT
        jsr cmp32
        beq @tofast
@bad:   lda #1
        sta FRAG
@end:   rts
@tofast: ldx #vT2
        ldy #vNXT
        jsr cpy32
        jsr inc32
@fast:  clc
        lda PTR
        adc ESZ
        sta PTR
        bcc @f1
        inc PTR+1
        lda PTR+1
        cmp #>(FATB+512)
        beq @tosl
@f1:    ldy #0
        lda (PTR),y
        cmp V+vT2
        bne @tosl
        iny
        lda (PTR),y
        cmp V+vT2+1
        bne @tosl
        lda FTYP
        beq @m
        iny
        lda (PTR),y
        cmp V+vT2+2
        bne @tosl
        iny
        lda (PTR),y
        and #$0F
        cmp V+vT2+3
        bne @tosl
@m:     ldx #vT2
        jsr inc32
        bra @fast
@tosl:  ldx #vCLUS
        ldy #vT2
        jsr cpy32
        jsr dec32
        bra @slow

; ============================================================================
; loadcfg: NEWCFG <- tabela da ROM (banco 4) se valida; NEWNAM <- nomes gravados se validos
loadcfg: ldx #CFGLEN-1
        lda ROMCFG+$60
        cmp #'C'
        beq @c
@z:     stz NEWCFG,x
        dex
        bpl @z
        bra @n
@c:     lda ROMCFG,x
        sta NEWCFG,x
        dex
        bpl @c
@n:     lda BK0                 ; nomes ficam no banco 0
        ldx #NAMLEN-1
        lda ROMNAM+44
        cmp #'N'
        beq @k
        lda #' '
@b:     sta NEWNAM,x
        dex
        bpl @b
        bra @f
@k:     lda ROMNAM,x
        sta NEWNAM,x
        dex
        bpl @k
@f:     lda BK4
        rts

; cpptr: CP = NEWCFG + DRV*24
cpptr:  lda DRV
        sta TMP
        asl
        adc TMP
        asl
        asl
        asl
        adc #<NEWCFG
        sta CP
        lda #>NEWCFG
        adc #0
        sta CP+1
        rts

; nmofs: Y = DRV*11 (deslocamento em NEWNAM)
nmofs:  lda DRV
        asl
        sta TMP
        asl
        asl
        adc TMP
        adc DRV
        tay
        rts

; resolve: para cada drive com nome guardado, acha a imagem e refaz a entrada da tabela
resolve: stz DRV
@d:     jsr cpptr
        jsr nmofs
        lda NEWNAM,y
        cmp #' '
        beq @off
        jsr find                ; A = indice na lista ou C=1
        bcs @off
        jsr lstptr
        ldy #23                 ; guarda a entrada atual
@o:     lda (CP),y
        sta OLD,y
        dey
        bpl @o
        jsr mkcfg               ; refaz (sem conferir contiguidade)
        ldy #19
@cmp:   lda (CP),y
        cmp OLD,y
        bne @chg
        dey
        bpl @cmp
        bra @nx                 ; igual ao que ja estava montado e conferido
@chg:   jsr getfcl              ; mudou: confere a contiguidade de novo
        jsr contig
        lda FRAG
        beq @nx
@off:   lda #0
        sta (CP)
@nx:    inc DRV
        lda DRV
        cmp #4
        bne @d
        rts

; find: procura NEWNAM[DRV] na lista. C=0 e A = indice se achou
find:   ldx #0
@i:     cpx NIMG
        bcs @no
        txa
        jsr lstptr
        jsr nmofs
        sty TMP
        ldy #0
@c:     phy
        tya
        clc
        adc TMP
        tay
        lda NEWNAM,y
        ply
        cmp (LP),y
        bne @nx
        iny
        cpy #11
        bne @c
        txa
        clc
        rts
@nx:    inx
        bra @i
@no:    sec
        rts

; mkcfg: monta a entrada (CP) da tabela a partir da imagem (LP)
mkcfg:  jsr getfcl
        lda #$80
        sta (CP)
        ldx #vCLUS
        ldy #vFCL
        jsr cpy32
        jsr c2l                 ; vLBA = inicio da imagem
        ldy #1
        ldx #0
@b:     lda V+vLBA,x
        sta (CP),y
        iny
        inx
        cpx #4
        bne @b
        lda V+vFSZ+3            ; blocos = tamanho/512, no maximo $FFFF
        lsr
        bne @max
        lda V+vFSZ+2
        ror
        sta TMP
        lda V+vFSZ+1
        ror
        sta (CP),y              ; +5
        iny
        lda TMP
        sta (CP),y              ; +6
        bra @r
@max:   lda #$FF
        sta (CP),y
        iny
        sta (CP),y
@r:     ldy #19                 ; LBA do dir -> +7..+10 ; indice -> +11 ; bytes 20-21, 26-31 -> +12..+19
@m:     lda mkmap-7,y
        phy
        tay
        lda (LP),y
        ply
        sta (CP),y
        dey
        cpy #7
        bcs @m
        ldy #23
        lda #0
@z:     sta (CP),y
        dey
        cpy #20
        bcs @z
        rts
mkmap:  .byte 19,20,21,22,23,11,12,13,14,15,16,17,18

; ============================================================================
; showmnt: mostra os 4 drives
showmnt: stz DRV
@d:     lda DRV
        clc
        adc #'1'
        jsr pch
        lda #':'
        jsr pch
        lda #' '
        jsr pch
        jsr nmofs
        lda NEWNAM,y
        cmp #' '
        beq @v
        jsr pname
        jsr cpptr
        lda (CP)
        bmi @ok
        jsr msg
        .byte " (AUSENTE)",0
        bra @ok
@v:     jsr msg
        .byte "-",0
@ok:    jsr CROUT
        inc DRV
        lda DRV
        cmp #4
        bne @d
        rts

; pname: imprime o nome 8.3 em NEWNAM,y (Y = inicio) ou (LP) se chamado em pnamel
pname:  ldx #0
@l:     lda NEWNAM,y
        jsr pnc
        iny
        inx
        cpx #11
        bne @l
        rts
pnamel: ldy #0
        ldx #0
@l:     lda (LP),y
        jsr pnc
        iny
        inx
        cpx #11
        bne @l
        rts
pnc:    cpx #8                  ; ponto antes da extensao
        bne @p
        pha
        lda #'.'
        jsr pch
        pla
@p:     jmp pch

; ============================================================================
; menu: C=1 se ESC
menu:   jsr HOME
        jsr msg
        .byte "CFFA 1.4 - IMAGENS (FAT",0
        lda FTYP
        beq @16
        jsr msg
        .byte "32)",0
        bra @h
@16:    jsr msg
        .byte "16)",0
@h:     jsr CROUT
        jsr showmnt
        jsr CROUT
        ldx #0
@l:     cpx NIMG
        bcs @p
        phx
        txa
        clc
        adc #'A'
        jsr pch
        lda #' '
        jsr pch
        txa
        jsr lstptr
        jsr pnamel
        lda #' '
        jsr pch
        ldy #18                 ; blocos = tamanho/512 (16 bits)
        lda (LP),y
        lsr
        bne @big
        dey
        lda (LP),y
        ror
        sta TMP
        dey
        lda (LP),y
        ror
        pha
        lda TMP
        jsr PRBYTE
        pla
        jsr PRBYTE
        bra @nl
@big:   jsr msg
        .byte "FFFF",0
@nl:    jsr CROUT
        plx
        inx
        bra @l
@p:     jsr msg
        .byte "1-4=DRIVE  RETURN=BOOT  ESC=SAIR ",0
        jsr RDKEY
        and #$7F
        cmp #$0D
        bne @k1
        clc                     ; RETURN: grava e segue o boot
        rts
@k1:    cmp #$1B
        bne @k2
        sec                     ; ESC: sai sem gravar
        rts
@k2:    sec
        sbc #'1'
        cmp #4
        bcc @k3
        jmp menu
@k3:    sta DRV
        jsr CROUT
        jsr msg
        .byte "IMAGEM (A-",0
        lda NIMG
        clc
        adc #'A'-1
        jsr pch
        jsr msg
        .byte ", ESPACO=VAZIO) ",0
        jsr RDKEY
        and #$7F
        cmp #' '
        beq @clr
        and #$DF                ; minuscula -> maiuscula
        sec
        sbc #'A'
        cmp NIMG
        bcs @again
        sta SEL
        jsr lstptr
        jsr getfcl
        jsr msg
        .byte " CONFERINDO...",0
        jsr contig
        lda FRAG
        beq @ok
        jsr msg
        .byte " FRAGMENTADA!",0
        jsr RDKEY
        bra @again
@ok:    jsr cpptr
        lda SEL
        jsr lstptr
        jsr mkcfg
        jsr nmofs
        ldx #0
@cn:    phy
        txa
        tay
        lda (LP),y
        ply
        sta NEWNAM,y
        iny
        inx
        cpx #11
        bne @cn
        bra @again
@clr:   jsr cpptr
        lda #0
        sta (CP)
        jsr nmofs
        ldx #11
        lda #' '
@cs:    sta NEWNAM,y
        iny
        dex
        bne @cs
@again: jmp menu

; ============================================================================
; save: grava na EEPROM so o que mudou (tabela no banco 4, nomes no banco 0)
save:   lda #'C'
        sta NEWCFG+$60
        lda #'N'
        sta NEWNAM+44
        lda #<NEWCFG
        sta PTR
        lda #>NEWCFG
        sta PTR+1
        lda #<ROMCFG
        sta ENT
        lda #>ROMCFG
        sta ENT+1
        lda #CFGLEN
        sta CNT
        lda #4
        sta BANKS
        jsr eewr
        lda #<NEWNAM
        sta PTR
        lda #>NEWNAM
        sta PTR+1
        lda #<ROMNAM
        sta ENT
        lda #>ROMNAM
        sta ENT+1
        lda #NAMLEN
        sta CNT
        stz BANKS
        jsr eewr
        stz DRVRST              ; o driver refaz o FatInit na proxima chamada
        rts

; eewr: copia CNT bytes de (PTR) para a EEPROM em (ENT), banco BANKS (0 ou 4); so os diferentes
eewr:   jsr romon
        ldy #0
@l:     lda BANKS
        beq @b0
        lda BK4
        bra @b1
@b0:    lda BK0
@b1:    lda (PTR),y
        cmp (ENT),y
        beq @nx
        sta WUNL                ; destrava
        sta (ENT),y             ; grava (a EEPROM leva ~3 ms)
        ldx #0
        lda #8
        sta TMP
@p:     lda (ENT),y             ; polling de dados: bit 7 invertido ate terminar
        cmp (PTR),y
        beq @d
        dex
        bne @p
        dec TMP
        bne @p
@d:     lda WUNL                ; trava
@nx:    iny
        cpy CNT
        bne @l
        lda BK4
        rts

ioerr:  ldx SAVSP
        txs
        jsr msg
        .byte "CFFA: ERRO DE LEITURA",0
        jsr CROUT
        jmp romon

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

