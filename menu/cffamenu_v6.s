; cffamenu_v6.s - menu da CFFA v1.2 (firmware 1.4) para imagens ProDOS em cartao FAT16/FAT32
; Tabajara Labs, 2026-11-20. Arquivo CFFAMENU.BIN na raiz do cartao FAT; o carregador do banco 0
; (estagio 1) carrega em $4000 e chama $4004. Tambem roda do monitor (carregado pela serial): 4007G.
;   $4000: "CFM1" (assinatura conferida pelo carregador)
;   $4004: entrada do boot   (X = $n0; so funciona no slot 7). Menu se houver tecla ou nada montado.
;   $4007: entrada de teste  (menu sempre)
; Grava a tabela de montagem no banco 4 ($CE80-$CEE0) e os nomes no banco 0 ($CEC0-$CEEC).
; v6: ordem alfabetica (pastas primeiro), letra pula para a inicial, subpastas (RETURN entra),
;     nome do volume ProDOS da imagem marcada na linha 23, protecao com SHIFT+1-4.
; v5 (firmware 1.5): segundo cartao (escravo) e protecao contra escrita por drive (tecla P).
;     O bit 4 do 4o byte do LBA (bit 28) marca o escravo: vale para as imagens e para o diretorio.
; v4: setas na mesma pagina reescrevem so as 2 linhas da barra; versao no titulo.
; v3: sem piscar (a tela so e apagada ao abrir; depois cada tecla escreve por cima).
; v2: nomes longos (VFAT), ate 64 imagens, tela com molduras (estilo Locksmith 6.0), setas e paginas.
; Montar: ca65 --cpu 65C02 cffamenu_v1.s && ld65 -t none -S $4000 cffamenu_v6.o -o CFFAMENU.BIN
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
NAMLEN  = 49                    ; 4x11 nomes, 'N', 4 bytes de cartao ($10 = escravo)

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
LFNT    = $6000                 ; nomes longos: 64 x 32 bytes (ate 31 caracteres + 0)
LST     = $6800                 ; 64 imagens x 24 bytes: nome 11, bytes 20-21 e 26-31 da entrada (8), LBA do dir (4), indice (1)
NEWCFG  = $6E00                 ; tabela nova (97 bytes)
NEWNAM  = $6E80                 ; nomes novos (45 bytes)
OLD     = $6EC0                 ; copia de uma entrada da tabela (24 bytes)
LBUF    = $6F00                 ; nome longo em montagem (64 bytes)
MSG     = $6F40                 ; mensagem da linha 23 (64 bytes)
NIMAX   = 64
LN      = $EE                   ; ponteiro para o nome longo

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
SCOL    = V+90
INV     = V+91
LIM     = V+92
NUM     = V+93                  ; 2 bytes
DIG     = V+95                  ; 5 bytes
NIT     = V+100
CUR     = V+101
TOP     = V+102
ROW     = V+103
ITEM    = V+104
LFOK    = V+105
LSUM    = V+106
CSUM    = V+107
MDRV    = V+108
FULL    = V+109                 ; 1 = redesenhar a tela toda
OCUR    = V+110
OTOP    = V+111
DEVB    = V+112                 ; $00 = mestre, $10 = escravo (bit 4 do byte 3 do LBA)
HASSL   = V+113                 ; 1 = escravo presente
VSER    = V+114                 ; numero de serie do volume FAT lido por ultimo (4 bytes)
MSER    = V+118                 ; numero de serie do volume do mestre
vSTCL   = 122                   ; cluster inicial da pasta a listar (4 bytes, deslocamento em V)
INSUB   = V+126                 ; 1 = listando uma subpasta
USESTCL = V+127                 ; 1 = scan2 comeca em vSTCL
ISFOLD  = V+128                 ; $80 = a entrada sendo guardada e uma pasta
OCURV   = V+129                 ; CUR para o qual VOLMSG foi calculado
KEYI    = V+130
T1F     = V+131
T2      = V+132
CMPA    = V+133
CMPB    = V+134
ORDER   = $7100                 ; ordem de exibicao (indices da lista)
VOLMSG  = $7140                 ; "VOLUME /NOME" da imagem marcada
LA      = $E3                   ; ponteiro auxiliar (nome A na comparacao)
VS0     = $6F80                 ; parametros da FAT do mestre (76 bytes + ESZ)
VS1     = $7000                 ; parametros da FAT do escravo                 ; drive escolhido no menu (o DRV e contador do draw)

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
@fat:   jsr scanall2
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
@some:  lda NIMG
        inc a
        sta NIT
        stz CUR
        stz TOP
        jsr setmsg
        .byte "QUALQUER TECLA ABRE O MENU...",0
        jsr cls
        jsr draw
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
        lda DEVB                ; bit 28 = cartao escravo (passa para todos os LBAs calculados)
        sta V+vLBA+3
        sta V+vPST+3
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
        lda V+vPST+3
        ora DEVB
        sta V+vPST+3
        sta V+vLBA+3
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
        ldx #3                  ; v5: numero de serie do volume (FAT32 em $43, FAT16 em $27)
@sn:    lda SBUF+$27,x
        ldy FTYP
        beq @s16
        lda SBUF+$43,x
@s16:   sta VSER,x
        dex
        bpl @sn
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
scan2:  lda USESTCL             ; v6: subpasta = cadeia de clusters a partir de vSTCL
        beq @norm
        ldx #vDCL
        ldy #vSTCL
        jsr cpy32
        bra @dc
@norm:  lda FTYP
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
        cmp #$E5                ; apagada
        beq @clr
        ldy #11
        lda (ENT),y
        cmp #$0F                ; pedaco de nome longo
        bne @sfn
        jmp lfnent
@sfn:   and #$08                ; rotulo de volume
        bne @clr
        lda (ENT),y
        and #$10
        beq @file
        lda (ENT)               ; pasta: ignora "."
        cmp #'.'
        bne @fold
        ldy #1
        lda (ENT),y
        cmp #' '
        beq @clr
@fold:  lda #$80
        sta ISFOLD
        jsr image
        bra @clr
@file:  stz ISFOLD
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
        bne @nx
        jsr image
        bra @clr
@nx:    inx
        inx
        inx
        cpx #9
        bne @ext
@clr:   stz LFOK
        rts
exts:   .byte "PO ","HDV","IMG"

; lfnent: guarda um pedaco do nome longo (13 caracteres UTF-16) em LBUF
lfnent: lda (ENT)
        and #$40                ; primeiro pedaco gravado (= ultimo do nome)?
        beq @cont
        ldy #63
        lda #0
@c:     sta LBUF,y
        dey
        bpl @c
        ldy #13
        lda (ENT),y
        sta LSUM
        lda #1
        sta LFOK
        bra @put
@cont:  lda LFOK
        beq @x
        ldy #13
        lda (ENT),y
        cmp LSUM
        bne @bad
@put:   lda (ENT)
        and #$1F
        beq @bad
        dec a                   ; posicao = (seq-1)*13
        sta TMP
        asl
        asl
        adc TMP                 ; *5
        asl                     ; *10
        adc TMP
        adc TMP
        adc TMP                 ; *13
        sta CNT
        ldx #0
@ch:    lda CNT
        cmp #63
        bcs @x                  ; so os 63 primeiros caracteres
        ldy lofs,x
        iny
        lda (ENT),y             ; byte alto
        dey
        cmp #$FF
        beq @end                ; $FFFF = enchimento
        cmp #0
        bne @q
        lda (ENT),y
        beq @end                ; $0000 = fim do nome
        cmp #$20
        bcc @q
        cmp #$7F
        bcc @st
@q:     lda #'?'
@st:    ldy CNT
        sta LBUF,y
        inc CNT
        inx
        cpx #13
        bne @ch
        rts
@end:   rts
@bad:   stz LFOK
@x:     rts
lofs:   .byte 1,3,5,7,9,14,16,18,20,22,24,28,30

image:  bit ISFOLD                ; pasta: aceita cluster 0 (".." apontando para a raiz)
        bmi @go
        ldy #$1A                ; cluster 0 = vazio: ignora
        lda (ENT),y
        iny
        ora (ENT),y
        ldy #$14
        ora (ENT),y
        iny
        ora (ENT),y
        beq @x
@go:    lda NIMG
        cmp #NIMAX
        bcs @x
        jsr lfnset              ; nome longo (se a soma de conferencia bater)
        lda NIMG
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
        ora ISFOLD              ; v6: bit 7 = pasta
        sta (LP),y              ; LP+23
        inc NIMG
@x:     rts
rawofs: .byte 20,21,26,27,28,29,30,31

; scanall: lista a raiz dos dois cartoes (fsinit do mestre ja feito) e ordena
scanall: stz DEVB
        jsr fsinit
scanall2:
        stz USESTCL
        stz INSUB
        jsr scan
        ldx #3
@ms:    lda VSER,x
        sta MSER,x
        dex
        bpl @ms
        ldx #0                  ; guarda os parametros do mestre
        jsr savefs
        stz HASSL
        jsr probesl
        bcs @nosl
        lda #$10
        sta DEVB
        jsr fsinit
        bcs @nosl
        ldx #3                  ; mesmo numero de serie = o mesmo cartao respondendo como escravo
@cs:    lda VSER,x
        cmp MSER,x
        bne @sl
        dex
        bpl @cs
        bra @nosl
@sl:    jsr scan2
        ldx #1
        jsr savefs
        inc HASSL
@nosl:  stz DEVB
        lda #0
        jsr usefs
        jsr sortl
        rts

; sortl: ORDER = indices da lista em ordem alfabetica (pastas primeiro). Insercao.
sortl:  ldx #0
@i:     cpx NIMG
        bcs @s
        txa
        sta ORDER,x
        inx
        bra @i
@s:     ldx #1
@o:     cpx NIMG
        bcs @done
        lda ORDER,x
        sta KEYI
        phx
        txa
        tay
@in:    cpy #0
        beq @put
        lda ORDER-1,y
        sta CMPB
        lda KEYI
        sta CMPA
        jsr less
        bcc @put
        lda ORDER-1,y
        sta ORDER,y
        dey
        bra @in
@put:   lda KEYI
        sta ORDER,y
        plx
        inx
        bra @o
@done:  rts

; less: C=1 se a imagem CMPA vem antes da CMPB. Preserva Y.
less:   phy
        lda CMPA
        jsr isfold
        sta T1F
        lda CMPB
        jsr isfold
        eor T1F
        bpl @same
        lda T1F
        bmi @lt                 ; A e pasta, B nao
        bra @ge
@same:  lda CMPA
        jsr lfnptr
        lda LN
        sta LA
        lda LN+1
        sta LA+1
        lda CMPB
        jsr lfnptr
        ldy #0
@c:     lda (LA),y
        jsr upc
        sta T2
        lda (LN),y
        jsr upc
        cmp T2
        bne @d
        lda T2
        beq @ge                 ; iguais
        iny
        cpy #31
        bne @c
        bra @ge
@d:     bcs @lt                 ; caractere de B maior: A vem antes
@ge:    ply
        clc
        rts
@lt:    ply
        sec
        rts
; isfold: A = indice -> A bit 7 = pasta (usa LP, Y)
isfold: jsr lstptr
        ldy #23
        lda (LP),y
        and #$80
        rts
; upc: minuscula -> maiuscula
upc:    cmp #'a'
        bcc @x
        cmp #'z'+1
        bcs @x
        and #$DF
@x:     rts

; savefs: X=0 mestre / 1 escravo: copia os parametros da FAT (V+0..V+75 e ESZ) para VS0/VS1
savefs: ldy #75
@l:     lda V,y
        cpx #0
        bne @1
        sta VS0,y
        bra @n
@1:     sta VS1,y
@n:     dey
        bpl @l
        lda ESZ
        cpx #0
        bne @2
        sta VS0+76
        rts
@2:     sta VS1+76
        rts
; usefs: A=0 mestre / 1 escravo: restaura os parametros da FAT daquele cartao
usefs:  tax
        ldy #75
@l:     cpx #0
        bne @1
        lda VS0,y
        bra @s
@1:     lda VS1,y
@s:     sta V,y
        dey
        bpl @l
        lda VS0+76
        cpx #0
        beq @e
        lda VS1+76
@e:     sta ESZ
        stz CVAL
        rts
; entfs: usa os parametros do cartao da imagem (LP): bit 4 do byte 3 do LBA do diretorio (LP+22)
entfs:  ldy #22
        lda (LP),y
        and #$10
        beq @m
        lda #1
@m:     jmp usefs
; probesl: C=0 se ha cartao escravo (RDY e DSC ligados)
probesl: lda #$F0
        sta HEAD
        ldx #0
@w:     lda STATUS
        cmp #$FF
        beq @no
        and #$D0
        cmp #$50
        beq @yes
        dex
        bne @w
@no:    lda #$E0
        sta HEAD
        sec
        rts
@yes:   lda #$E0
        sta HEAD
        clc
        rts

; LP = LST + A*24 (A < 64)
lstptr: sta TMP
        asl
        adc TMP                 ; A*3 (ate 189)
        stz LP+1
        asl
        rol LP+1
        asl
        rol LP+1
        asl
        rol LP+1
        sta LP
        lda LP+1
        adc #>LST
        sta LP+1
        rts

; LN = LFNT + A*32
lfnptr: stz LN+1
        asl
        rol LN+1
        asl
        rol LN+1
        asl
        rol LN+1
        asl
        rol LN+1
        asl
        rol LN+1
        sta LN
        lda LN+1
        clc
        adc #>LFNT
        sta LN+1
        rts

; lfnset: confere a soma do nome curto (ENT) com a dos pedacos; copia LBUF para LFNT[NIMG] ou zera
lfnset: lda NIMG
        jsr lfnptr
        lda #0
        sta (LN)
        lda LFOK
        beq @syn
        stz CSUM
        ldy #0
@s:     lda CSUM
        lsr
        bcc @s1
        ora #$80
@s1:    clc
        adc (ENT),y
        sta CSUM
        iny
        cpy #11
        bne @s
        cmp LSUM
        bne @syn
        ldy #30
        lda #0
        sta (LN),y
        iny
        sta (LN),y
        dey
@c:     dey
        bmi @x
        lda LBUF,y
        sta (LN),y
        bra @c
@x:     rts
@syn:   stz CNT                 ; v6: sem nome longo: "NOME.EXT" a partir do nome 8.3
        ldx #0
@a:     txa
        tay
        lda (ENT),y
        cpx #8
        bne @b
        cmp #' '
        beq @end
        pha
        lda #'.'
        jsr @put
        pla
@b:     cmp #' '
        beq @sk
        jsr @put
@sk:    inx
        cpx #11
        bne @a
@end:   lda #0
@put:   ldy CNT
        sta (LN),y
        inc CNT
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
@f:     ldx #3                  ; v5: cartao dos drives ($FF = nome gravado pelo menu antigo -> mestre)
@d:     lda NEWNAM+45,x
        and #$10
        cmp NEWNAM+45,x
        beq @d1
        stz NEWNAM+45,x
@d1:    dex
        bpl @d
        lda BK4
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
        lda (CP)                ; v6: montada antes? a entrada de diretorio gravada continua igual?
        bpl @fnd
        jsr chkdir
        bcc @nx                 ; sim (vale tambem para imagens em subpastas)
@fnd:   jsr find                ; A = indice na lista ou C=1
        bcs @off
        jsr lstptr
        jsr entfs               ; v5: parametros da FAT do cartao da imagem
        ldy #23                 ; guarda a entrada atual
@o:     lda (CP),y
        sta OLD,y
        dey
        bpl @o
        jsr mkcfg               ; refaz (sem conferir contiguidade)
        lda OLD                 ; v5: mantem a protecao contra escrita
        and #$40
        ora (CP)
        sta (CP)
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

; chkdir: le o setor de diretorio da tabela (CP) e confere nome, cluster e tamanho da entrada.
;   C=0 se tudo igual. Usa SBUF.
chkdir: ldy #7
        ldx #0
@l:     lda (CP),y
        sta V+vLBA,x
        iny
        inx
        cpx #4
        bne @l
        jsr rdsec_s
        bcs @no
        ldy #11                 ; ENT = SBUF + indice*32
        lda (CP),y
        and #$0F
        pha
        lsr
        lsr
        lsr
        clc
        adc #>SBUF
        sta ENT+1
        pla
        and #7
        asl
        asl
        asl
        asl
        asl
        sta ENT
        jsr nmofs
        sty TMP
        ldy #0
@n:     phy
        tya
        clc
        adc TMP
        tay
        lda NEWNAM,y
        ply
        cmp (ENT),y
        bne @no
        iny
        cpy #11
        bne @n
        ldx #7                  ; bytes 20-21, 26-31 da entrada x tabela +12..+19
@r:     ldy rawofs,x
        lda (ENT),y
        pha
        txa
        clc
        adc #12
        tay
        pla
        cmp (CP),y
        bne @no
        dex
        bpl @r
        clc
        rts
@no:    sec
        rts

; find: procura NEWNAM[DRV] na lista. C=0 e A = indice se achou
find:   ldx #0
@i:     cpx NIMG
        bcs @no
        txa
        jsr isfold              ; v6: pastas nao contam
        bmi @nx
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
        ldy #22                 ; v5: mesmo cartao?
        lda (LP),y
        and #$10
        ldy DRV
        cmp NEWNAM+45,y
        bne @nx
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
; TELA (v2): escrita direta na memoria de video, molduras em video inverso (estilo Locksmith 6.0)
;   linha 0      titulo (inverso)
;   linhas 2-7   moldura de cima: os 4 drives
;   linhas 9-21  moldura de baixo: imagens do cartao (11 por pagina) com barra de selecao
;   linha 22     ajuda ; linha 23 mensagens
BASCALC = $FBC1
BASL    = $28
CHP     = $24
CVP     = $25
LROW0   = 10                    ; primeira linha da lista
LROWS   = 11                    ; linhas visiveis da lista
NCOL    = 29                    ; caracteres do nome

; setpos: A = linha, X = coluna
setpos: stx SCOL
        jmp BASCALC

; putc: escreve A (ASCII) na posicao atual; INV <> 0 = inverso. Preserva X e Y.
putc:   phy
        ldy SCOL
        cpy #40
        bcs @x
        and #$7F
        bit INV
        bpl @n
        cmp #$60                ; inverso: minuscula vira maiuscula
        bcc @i
        and #$DF
@i:     and #$3F
        bra @w
@n:     ora #$80
@w:     sta (BASL),y
        inc SCOL
@x:     ply
        rts

; puts: texto logo apos o JSR (termina em 0)
puts:   pla
        sta MP
        pla
        sta MP+1
@m:     inc MP
        bne @m2
        inc MP+1
@m2:    lda (MP)
        beq @d
        jsr putc
        bra @m
@d:     lda MP+1
        pha
        lda MP
        pha
        rts

; fillto: preenche com espacos (no modo INV atual) ate a coluna X
fillto: cpx SCOL
        beq @x
        bcc @x
        lda #' '
        jsr putc
        bra fillto
@x:     rts

; frame: linha A toda em inverso, com o texto (MP) na coluna 2 (usa puts antes? nao: chamado com texto inline)
border: ldx #0
        jsr setpos
        lda #$FF
        sta INV
        ldx #2
        jsr fillto
        jmp puts                ; o texto inline vem do chamador (puts usa o retorno dele)

; endrow: termina a linha atual com espacos inversos ate a coluna 40
endrow: lda #$FF
        sta INV
        ldx #40
        jmp fillto

; side: comeca uma linha interna: coluna 0 inversa, coluna 1 normal
side:   ldx #0
        jsr setpos
        lda #$FF
        sta INV
        lda #' '
        jsr putc
        stz INV
        lda #' '
        jmp putc

; closerow: completa a linha interna com espacos normais ate a coluna 39 e poe a borda
closerow: stz INV
        ldx #39
        jsr fillto
        lda #$FF
        sta INV
        lda #' '
        jmp putc

; ----------------------------------------------------------------------------
; nome da imagem A (indice na lista) na posicao atual, ate NCOL caracteres
pimg:   pha
        jsr lfnptr
        lda #30                 ; o nome vai no maximo ate a coluna 29 (30 = marca E)
        sta LIM
        ldy #0
        lda (LN)
        beq @short
@l:     lda (LN),y
        beq @f
        jsr putl
        iny
        cpy #31
        bne @l
@f:     pla
        rts
@short: pla
        jsr lstptr
        ldy #0
@s:     lda (LP),y
        cmp #' '
        beq @sk
        jsr putl
@sk:    iny
        cpy #8
        bne @s2
        lda (LP),y              ; extensao comeca: ponto (se houver extensao)
        cmp #' '
        beq @s3
        lda #'.'
        jsr putl
@s2:    cpy #11
        bne @s
@s3:    rts
; putl: putc limitado a LIM
putl:   pha
        lda SCOL
        cmp LIM
        pla
        bcs @x
        jmp putc
@x:     rts

; tamanho da imagem A em KB, 6 colunas ("32767K")
psize:  jsr lstptr
        ldy #18                 ; blocos = tamanho/512 (max $FFFF); KB = blocos/2
        lda (LP),y
        lsr
        bne @max
        dey
        lda (LP),y
        ror
        sta NUM+1
        dey
        lda (LP),y
        ror
        sta NUM
        bra @kb
@max:   lda #$FF
        sta NUM
        sta NUM+1
@kb:
pskb:   lsr NUM+1
        ror NUM
        ldx #4                  ; 5 digitos decimais
@d:     lda #0                  ; NUM / 10 -> NUM, resto em A
        ldy #16
@b:     asl NUM
        rol NUM+1
        rol a
        cmp #10
        bcc @nb
        sbc #10
        inc NUM
@nb:    dey
        bne @b
        ora #'0'
        sta DIG,x
        dex
        bpl @d
        ldx #0                  ; zeros a esquerda viram espacos
@z:     lda DIG,x
        cmp #'0'
        bne @p
        lda #' '
        sta DIG,x
        inx
        cpx #4
        bne @z
@p:     ldx #0
@o:     lda DIG,x
        jsr putc
        inx
        cpx #5
        bne @o
        lda #'K'
        jmp putc

; ----------------------------------------------------------------------------
; draw: redesenha a tela inteira
; cls: apaga a tela (so ao abrir o menu)
cls:    ldx #23
@cl:    phx
        txa
        ldx #0
        jsr setpos
        stz INV
        ldx #40
        jsr fillto
        plx
        dex
        bpl @cl
        rts

; draw: redesenha tudo por cima (cada linha e escrita inteira: nada pisca)
draw:   lda #0                  ; titulo
        jsr border
        .byte "CFFA 1.5 MENU V6 - CARTAO FAT",0
        lda VS0+71              ; tipo de FAT do cartao principal (FTYP = V+71)
        beq @t16
        jsr puts
        .byte "32",0
        bra @t
@t16:   jsr puts
        .byte "16",0
@t:     jsr endrow
        lda #2                  ; moldura de cima
        jsr border
        .byte " DRIVES ",0
        jsr endrow
        stz DRV
@dr:    lda DRV
        clc
        adc #3
        jsr side
        lda DRV
        clc
        adc #'1'
        jsr putc
        jsr cpptr               ; v5: P = protegido contra escrita
        lda (CP)
        and #$C0
        cmp #$C0
        lda #' '
        bcc @np
        lda #'P'
@np:    jsr putc
        lda #' '
        jsr putc
        jsr pdrive
        jsr closerow
        inc DRV
        lda DRV
        cmp #4
        bne @dr
        lda #7
        jsr border
        .byte 0
        jsr endrow
        lda #9                  ; moldura de baixo
        jsr border
        .byte " ",0
        lda INSUB
        beq @tr
        jsr puts
        .byte "NA PASTA: ",0
        bra @tn
@tr:    jsr puts
        .byte "IMAGENS NO CARTAO: ",0
@tn:
        lda NIMG
        jsr pdec2
        jsr puts
        .byte "  PAGINA ",0
        lda TOP                 ; pagina = TOP/11 + 1
        ldx #0
@pg:    cmp #LROWS
        bcc @pg2
        sbc #LROWS
        inx
        bra @pg
@pg2:   txa
        inc a
        jsr pdec2
        jsr puts
        .byte " DE ",0
        lda NIT                 ; paginas = (NIT+10)/11
        clc
        adc #LROWS-1
        ldx #0
@pq:    cmp #LROWS
        bcc @pq2
        sbc #LROWS
        inx
        bra @pq
@pq2:   txa
        jsr pdec2
        lda #' '
        jsr putc
        jsr endrow
        stz ROW
@ir:    jsr drow
        inc ROW
        lda ROW
        cmp #LROWS
        bne @ir
        lda #LROW0+LROWS
        jsr border
        .byte 0
        jsr endrow
        jmp dmsg

; drow: desenha a linha ROW da lista (item TOP+ROW)
drow:   lda ROW
        clc
        adc #LROW0
        jsr side
        lda ROW
        clc
        adc TOP
        cmp NIT
        bcc @in0
        jmp @ie                 ; linha vazia
@in0:   sta ITEM
        cmp CUR
        bne @in
        lda #$FF                ; barra de selecao
        sta INV
@in:    lda ITEM
        bne @img
        jsr puts
        .byte "(NENHUMA: ESVAZIA O DRIVE)",0
        bra @ie2
@img:   dec a
        tax
        lda ORDER,x             ; v6: indice na ordem alfabetica
        pha
        jsr isfold
        bmi @fd
        pla
        pha
        jsr pimg
        pla
        pha
        jsr emark
        pla
        jsr psize
        bra @ie2
@fd:    pla                     ; pasta
        pha
        jsr lfnptr
        lda (LN)
        cmp #'.'
        bne @fn
        ldy #1
        lda (LN),y
        cmp #'.'
        bne @fn
        pla
        jsr puts
        .byte ".. (PASTA DE CIMA)",0
        bra @ie2
@fn:    pla
        jsr pimg
        ldx #31
        jsr fillto
        jsr puts
        .byte " PASTA",0
@ie2:   ldx #38
        jsr fillto
@ie:    jmp closerow

; dmsg: linhas 22 (ajuda) e 23 (mensagem)
dmsg:
        lda #22
        ldx #0
        jsr setpos
        stz INV
        jsr puts
        .byte "1-4:MONTA SHIFT 1-4:PROT RET:BOOT ESC",0
        ldx #40
        jsr fillto
        lda #23
        ldx #0
        jsr setpos
        lda #' '
        jsr putc
        ldy #0
        lda MSG
        bne @ms
@vv:    lda VOLMSG,y            ; v6: sem mensagem: nome do volume da imagem marcada
        beq @mx
        jsr putc
        iny
        bra @vv
@ms:    lda MSG,y               ; mensagem de estado
        beq @mx
        jsr putc
        iny
        bra @ms
@mx:    ldx #40                 ; apaga o resto da mensagem anterior
        jmp fillto


; pdrive: conteudo do drive DRV na moldura de cima
pdrive: jsr nmofs
        lda NEWNAM,y
        cmp #' '
        bne @has
        jsr puts
        .byte "-",0
        rts
@has:   jsr find
        bcs @abs
        pha
        jsr pimg
        pla
        pha
        jsr emark
        jsr cpptr
        lda (CP)
        bpl @fr
        pla
        jmp psize
@fr:    pla
        jsr puts
        .byte "FRAG.",0
        rts
@abs:   jsr nmofs               ; nome 8.3 formatado
        ldx #0
@n:     lda NEWNAM,y
        cpx #8
        bne @n1
        cmp #' '
        beq @n3
        pha
        lda #'.'
        jsr putc
        pla
@n1:    cmp #' '
        beq @n2
        jsr putc
@n2:    iny
        inx
        cpx #11
        bne @n
@n3:    jsr cpptr
        lda (CP)
        bmi @mnt
        ldx #31
        jsr fillto
        jsr puts
        .byte "AUSENTE",0
        rts
@mnt:   ldx #30                 ; v6: montada e conferida, mas em outra pasta: tamanho pela tabela
        jsr fillto
        ldy DRV
        lda NEWNAM+45,y
        beq @me
        lda #'E'
        jsr putc
@me:    ldx #32
        jsr fillto
        ldy #5
        lda (CP),y
        sta NUM
        iny
        lda (CP),y
        sta NUM+1
        jmp pskb

; emark: completa ate a coluna 31 e marca E se a imagem A estiver no cartao escravo
emark:  jsr lstptr
        ldx #30
        jsr fillto
        ldy #22
        lda (LP),y
        and #$10
        beq @m
        lda #'E'
        jsr putc
        lda #' '
        jmp putc
@m:     lda #' '
        jsr putc
        jmp putc

; pdec2: A (0-99) em decimal
pdec2:  ldx #0
@t:     cmp #10
        bcc @u
        sbc #10
        inx
        bra @t
@u:     pha
        txa
        beq @1
        ora #'0'
        jsr putc
@1:     pla
        ora #'0'
        jmp putc

; setmsg: copia o texto inline para MSG (linha 23)
setmsg: pla
        sta MP
        pla
        sta MP+1
        ldy #0
@l:     inc MP
        bne @l2
        inc MP+1
@l2:    lda (MP)
        sta MSG,y
        beq @d
        iny
        bra @l
@d:     lda MP+1
        pha
        lda MP
        pha
        rts

; key: RDKEY com o cursor escondido no canto da linha 23
key:    lda #23
        sta CVP
        jsr BASCALC
        lda #39
        sta CHP
        jsr RDKEY
        and #$7F
        rts

; ============================================================================
; menu: C=1 se ESC
menu:   lda NIMG
        inc a
        sta NIT                 ; itens = (nenhuma) + imagens
        stz CUR
        stz TOP
        stz MSG
        jsr cls
        lda #1
        sta FULL
        lda #$FF
        sta OCURV
@loop:  jsr fixtop
        lda CUR                 ; v6: nome do volume quando a barra muda
        cmp OCURV
        beq @nv
        sta OCURV
        jsr volinfo
@nv:
        lda FULL
        bne @full
        lda TOP
        cmp OTOP
        bne @full
        lda OCUR                ; mesma pagina: so a linha que perde e a que ganha a barra
        sec
        sbc TOP
        sta ROW
        jsr drow
        lda CUR
        sec
        sbc TOP
        sta ROW
        jsr drow
        jsr dmsg
        bra @key
@full:  jsr draw
        stz FULL
@key:   lda CUR
        sta OCUR
        lda TOP
        sta OTOP
        jsr key
        pha
        lda MSG                 ; havia mensagem: apagar com redesenho completo
        beq @nm
        inc FULL
@nm:    pla
        stz MSG
        cmp #$0B                ; seta para cima
        bne @k1
        lda CUR
        bne @u1
        jmp @loop
@u1:    dec CUR
        jmp @loop
@k1:    cmp #$0A                ; seta para baixo
        bne @k2
        lda CUR
        inc a
        cmp NIT
        bcc @d1
        jmp @loop
@d1:    sta CUR
        jmp @loop
@k2:    cmp #$08                ; seta para a esquerda: pagina anterior
        bne @k3
        lda CUR
        sec
        sbc #LROWS
        bcs @k2b
        lda #0
@k2b:   sta CUR
        lda TOP
        sec
        sbc #LROWS
        bcs @k2c
        lda #0
@k2c:   sta TOP
        jmp @loop
@k3:    cmp #$15                ; seta para a direita: proxima pagina
        bne @k4
        lda TOP
        clc
        adc #LROWS
        cmp NIT
        bcc @r1
        jmp @loop
@r1:    sta TOP
        lda CUR
        clc
        adc #LROWS
        cmp NIT
        bcc @k3b
        lda NIT
        dec a
@k3b:   sta CUR
        jmp @loop
@k4:    cmp #$0D
        beq @k4a
        jmp @k5
@k4a:   lda CUR
        beq @boot
        dec a
        tax
        lda ORDER,x
        sta SEL
        jsr isfold
        bmi @dir
@boot:  clc
        rts
@dir:   lda SEL                 ; v6: entra na pasta (ou volta, se for "..")
        jsr lstptr
        jsr entfs
        ldy #13                 ; cluster da pasta: baixo em +13/+14, alto em +11/+12
        lda (LP),y
        sta V+vSTCL
        iny
        lda (LP),y
        sta V+vSTCL+1
        stz V+vSTCL+2
        stz V+vSTCL+3
        lda FTYP
        beq @d16
        ldy #11
        lda (LP),y
        sta V+vSTCL+2
        iny
        lda (LP),y
        sta V+vSTCL+3
@d16:   lda V+vSTCL
        ora V+vSTCL+1
        ora V+vSTCL+2
        ora V+vSTCL+3
        bne @sub
        jsr scanall             ; ".." da raiz: lista os dois cartoes de novo
        bra @dn
@sub:   stz NIMG
        lda #1
        sta USESTCL
        sta INSUB
        jsr scan2
        stz USESTCL
        jsr sortl
@dn:    lda NIMG
        inc a
        sta NIT
        stz CUR
        stz TOP
        lda #$FF
        sta OCURV
        inc FULL
        jsr cls
        jmp @loop
@k5:    cmp #$1B
        bne @k6
        sec
        rts
@k6:    ldx #4                  ; v6: SHIFT+1-4 (! @ " # $) protege/libera
@sh:    cmp @shtab,x
        beq @prot
        dex
        bpl @sh
        jsr upc                 ; letra: pula para a primeira imagem com essa inicial
        cmp #'A'
        bcc @k7
        cmp #'Z'+1
        bcs @k7
        sta T2
        ldx #0
@lf:    cpx NIMG
        bcs @lnf
        phx
        lda ORDER,x
        jsr lfnptr
        lda (LN)
        jsr upc
        plx
        cmp T2
        beq @lok
        inx
        bra @lf
@lok:   inx
        stx CUR
@lnf:   jmp @loop
@prot:  lda @shdrv,x
        sta DRV
        jsr cpptr
        lda (CP)
        bpl @p9                 ; so drive montado
        eor #$40
        sta (CP)
@p9:    inc FULL
        jmp @loop
@shtab: .byte "!@",$22,"#$"
@shdrv: .byte 0,1,1,2,3
@k7:    sec
        sbc #'1'
        cmp #4
        bcc @mnt
        jmp @loop
@mnt:   sta MDRV
        sta DRV
        jsr cpptr
        lda CUR
        bne @img
        inc FULL
        lda #0                  ; (nenhuma): esvazia o drive
        sta (CP)
        ldy MDRV
        sta NEWNAM+45,y
        jsr nmofs
        ldx #11
        lda #' '
@cs:    sta NEWNAM,y
        iny
        dex
        bne @cs
        jmp @loop
@img:   dec a
        tax
        lda ORDER,x
        sta SEL
        jsr isfold
        bpl @im2
        jmp @loop               ; pasta: nada a montar
@im2:   inc FULL
        jsr setmsg
        .byte "CONFERINDO A IMAGEM...",0
        jsr draw
        lda MDRV
        sta DRV
        lda SEL
        jsr lstptr
        jsr entfs
        jsr getfcl
        jsr contig
        lda FRAG
        beq @ok
        jsr setmsg
        .byte "IMAGEM FRAGMENTADA: COPIE DE NOVO NUM CARTAO FORMATADO",0
        jmp @loop
@ok:    lda MDRV
        sta DRV
        jsr cpptr
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
        ldy #22                 ; v5: cartao da imagem
        lda (LP),y
        and #$10
        ldy MDRV
        sta NEWNAM+45,y
        jsr setmsg
        .byte "MONTADA.",0
        jmp @loop

; volinfo: VOLMSG = "VOLUME /NOME" lido do bloco 2 da imagem marcada (vazio se pasta ou sem ProDOS)
volinfo: stz VOLMSG
        lda CUR
        beq @x
        dec a
        tax
        lda ORDER,x
        pha
        jsr isfold
        bmi @xp
        pla
        jsr lstptr
        jsr entfs
        jsr getfcl
        ldx #vCLUS
        ldy #vFCL
        jsr cpy32
        jsr c2l
        ldx #vLBA
        jsr inc32
        jsr inc32
        jsr rdsec_s
        bcs @x
        lda SBUF                ; bloco 2 = diretorio do volume: anterior = 0, tipo $F
        ora SBUF+1
        bne @no
        lda SBUF+4
        and #$F0
        cmp #$F0
        bne @no
        ldy #0
@c:     lda @t,y
        sta VOLMSG,y
        beq @nm
        iny
        bra @c
@nm:    lda SBUF+4
        and #$0F
        tax
        ldy #0
@n:     lda SBUF+5,y
        sta VOLMSG+8,y
        iny
        dex
        bne @n
        lda #0
        sta VOLMSG+8,y
@x:     rts
@xp:    pla
        rts
@no:    ldy #0
@c2:    lda @t2,y
        sta VOLMSG,y
        beq @x
        iny
        bra @c2
@t:     .byte "VOLUME /",0
@t2:    .byte "SEM VOLUME PRODOS NO BLOCO 2",0

; fixtop: mantem CUR visivel
fixtop: lda CUR
        cmp TOP
        bcs @a
        sta TOP
@a:     lda TOP
        clc
        adc #LROWS
        cmp CUR
        beq @b
        bcs @x
@b:     lda CUR
        sec
        sbc #LROWS-1
        sta TOP
@x:     rts

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
        lda V+vLBA+3            ; v5: Head primeiro (bit 4 = escravo), depois espera o cartao
        and #$1F
        ora #$E0
        sta HEAD
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

