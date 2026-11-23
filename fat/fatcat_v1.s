; fatcat_v1.s - prototipo na RAM: le cartao FAT16/FAT32 pela CFFA (slot 7) e lista imagens ProDOS
; Apple IIe Enhanced (65C02). Somente leitura. Carregar em $6000 e rodar com 6000G.
; - aceita cartao com MBR (particao 1 tipo 04/06/0E = FAT16, 0B/0C = FAT32) ou "superfloppy" (VBR no setor 0)
; - lista arquivos .PO .HDV .IMG da raiz: tamanho em blocos, cluster inicial, LBA inicial,
;   e confere se os clusters sao contiguos (condicao para montar como volume ProDOS)
; Montar: ca65 --cpu 65C02 fatcat_v1.s && ld65 -t none -S $6000 fatcat_v1.o -o fatcat_v1.bin
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
KBD     = $C000
KBDSTRB = $C010

PTR     = $06           ; ponteiro de buffer (rdsec / fatnext)
ENT     = $08           ; ponteiro para a entrada de diretorio no buffer SBUF
MP      = $FA           ; ponteiro do msg
TMP     = $FC
CNT     = $FD

SBUF     = $6800         ; buffer de setor (MBR, VBR, diretorio) 512 bytes
FATB    = $6A00         ; buffer do setor de FAT (cache) 512 bytes
V       = $6C00         ; variaveis de 32 bits (indice X/Y = deslocamento)

; variaveis de 4 bytes (little endian), deslocamento dentro de V
vLBA    = 0             ; setor a ler
vPST    = 4             ; inicio da particao
vFATST  = 8             ; inicio da FAT 1
vROOTST = 12            ; inicio do diretorio raiz (FAT16)
vDATAST = 16            ; inicio da area de dados (cluster 2)
vROOTCL = 20            ; cluster do diretorio raiz (FAT32)
vFATSZ  = 24            ; setores por FAT
vT1     = 28            ; temporario
vCLUS   = 32            ; cluster atual (entrada de fatnext)
vFCACHE = 36            ; LBA do setor de FAT no buffer FATB
vDIRL   = 40            ; setor atual do diretorio
vFCL    = 44            ; cluster inicial do arquivo
vFSZ    = 48            ; tamanho do arquivo (bytes)
vNCL    = 52            ; clusters contados no arquivo
vT2     = 56            ; temporario
vNXT    = 60            ; saida de fatnext
vDCL    = 64            ; cluster atual do diretorio (FAT32)
SPCV    = V+68          ; setores por cluster
SPSH    = V+69          ; log2(setores por cluster)
NFAT    = V+70          ; numero de FATs
FTYP    = V+71          ; 0 = FAT16, 1 = FAT32
RSECS   = V+72          ; setores restantes do diretorio raiz (FAT16), 2 bytes
SLEFT   = V+74          ; setores restantes no cluster do diretorio (FAT32)
CVAL    = V+75          ; cache de FAT valido?
NFILE   = V+76          ; imagens encontradas
FRAG    = V+77          ; arquivo fragmentado?
FOFS    = V+78          ; deslocamento da entrada no setor de FAT (2 bytes)
SAVSP   = V+80
ESZ     = V+81          ; bytes por entrada de FAT (2 ou 4)          ; pilha no inicio (para sair em erro)

; ============================================================================
start:  tsx
        stx SAVSP
        jsr msg
        .byte "FATCAT V1 - CFFA SLOT 7",0
        jsr CROUT
        stz CVAL
        stz NFILE
        ldx #vLBA
        jsr zero32
        ldx #vPST
        jsr zero32
        jsr rdsec_s             ; setor 0
        bcc @s0
        jmp ioerr
@s0:    lda SBUF+$1FE
        cmp #$55
        bne nofat
        lda SBUF+$1FF
        cmp #$AA
        bne nofat
        jsr isvbr               ; setor 0 ja e o VBR? (cartao sem tabela de particoes)
        bcc @vbr
        lda SBUF+$1C2            ; tipo da particao 1
        sta TMP
        jsr msg
        .byte "MBR: PARTICAO 1 TIPO ",0
        lda TMP
        jsr PRBYTE
        jsr CROUT
        lda TMP
        ldx #5
@tp:    cmp fattypes,x
        beq @ok
        dex
        bpl @tp
        bra nofat
@ok:    ldx #3
@cp:    lda SBUF+$1C6,x
        sta V+vPST,x
        sta V+vLBA,x
        dex
        bpl @cp
        jsr rdsec_s
        bcc @r1
        jmp ioerr
@r1:    jsr isvbr
        bcs nofat
        bra parse
@vbr:   jsr msg
        .byte "SEM MBR (VBR NO SETOR 0)",0
        jsr CROUT
        bra parse

nofat:  jsr msg
        .byte "NAO E FAT16/FAT32 (CARTAO PRODOS CRU?)",0
        jmp CROUT

fattypes: .byte $04,$06,$0E,$0B,$0C,$01

; ---- isvbr: C=0 se SBUF parece um setor de boot FAT (salto, 512 bytes/setor, 1-2 FATs)
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
; interpreta o BPB
parse:  lda SBUF+$0D             ; setores por cluster (potencia de 2)
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
        ; FATST = PST + reservados
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
        ; tamanho da FAT: FAT16 em $16, FAT32 em $24
        ldx #vFATSZ
        jsr zero32
        lda SBUF+$16
        ora SBUF+$17
        beq @f32
        lda SBUF+$3A             ; "FAT12   " / "FAT16   " -> rejeita FAT12
        cmp #'2'
        bne @f16
        jsr msg
        .byte "FAT12 NAO SUPORTADA",0
        jmp CROUT
@f16:   stz FTYP
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
@fz:    ; ROOTST = FATST + NFAT*FATSZ
        ldx #vROOTST
        ldy #vFATST
        jsr cpy32
        lda NFAT
        sta CNT
@nf:    ldy #vFATSZ
        jsr add32
        dec CNT
        bne @nf
        ; DATAST = ROOTST + setores do raiz (FAT16: entradas/16)
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
        ; relatorio
        lda FTYP
        bne @p32
        jsr msg
        .byte "FAT16",0
        bra @p1
@p32:   jsr msg
        .byte "FAT32",0
@p1:    jsr msg
        .byte "  PART ",0
        ldx #vPST
        jsr pr32
        jsr msg
        .byte "  SET/CL ",0
        lda SPCV
        jsr PRBYTE
        jsr CROUT
        jsr msg
        .byte "FAT ",0
        ldx #vFATST
        jsr pr32
        jsr msg
        .byte "  DADOS ",0
        ldx #vDATAST
        jsr pr32
        jsr CROUT
        jsr msg
        .byte "ARQUIVO      BLOCOS CLUSTER  LBA",0
        jsr CROUT

; ============================================================================
; percorre o diretorio raiz
        lda FTYP
        bne dir32
; ---- FAT16: regiao fixa
        ldx #vDIRL
        ldy #vROOTST
        jsr cpy32
@ds:    lda RSECS
        ora RSECS+1
        beq dirend
        jsr dirsec
        bcs dirend
        ldx #vDIRL
        jsr inc32
        lda RSECS
        bne @dd
        dec RSECS+1
@dd:    dec RSECS
        bra @ds
; ---- FAT32: cadeia de clusters
dir32:  ldx #vDCL
        ldy #vROOTCL
        jsr cpy32
@dc:    ldx #vCLUS
        ldy #vDCL
        jsr cpy32
        jsr c2l                 ; LBA = setor inicial do cluster
        ldx #vDIRL
        ldy #vLBA
        jsr cpy32
        lda SPCV
        sta SLEFT
@dsc:   jsr dirsec
        bcs dirend
        ldx #vDIRL
        jsr inc32
        dec SLEFT
        bne @dsc
        ldx #vCLUS
        ldy #vDCL
        jsr cpy32
        jsr fatnext
        bcs dirend
        ldx #vDCL
        ldy #vNXT
        jsr cpy32
        bra @dc

dirend: jsr msg
        .byte "IMAGENS: ",0
        lda NFILE
        jsr PRBYTE
        jsr CROUT
        rts

; ---- le o setor vDIRL e processa as 16 entradas; C=1 = fim do diretorio
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
        sec                     ; nome[0]=0 -> fim
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

; ---- processa uma entrada de diretorio em (ENT)
entry:  lda (ENT)
        cmp #$E5                ; apagada
        beq @x
        ldy #11
        lda (ENT),y             ; atributos
        cmp #$0F                ; nome longo (LFN)
        beq @x
        and #$18                ; diretorio / rotulo de volume
        bne @x
        ; extensao
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

image:  inc NFILE
        ; nome 8.3
        ldy #0
@n:     lda (ENT),y
        jsr pch
        iny
        cpy #8
        bne @n
        lda #'.'
        jsr pch
@n2:    lda (ENT),y
        jsr pch
        iny
        cpy #11
        bne @n2
        lda #' '
        jsr pch
        ; tamanho em bytes e em blocos (bytes/512)
        ldy #$1C
        ldx #0
@sz:    lda (ENT),y
        sta V+vFSZ,x
        iny
        inx
        cpx #4
        bne @sz
        lda V+vFSZ+3            ; blocos = FSZ >> 9 (3 bytes)
        lsr
        sta TMP                 ; byte 2
        lda V+vFSZ+2
        ror
        sta CNT                 ; byte 1
        lda V+vFSZ+1
        ror
        pha                     ; byte 0
        lda TMP
        jsr PRBYTE
        lda CNT
        jsr PRBYTE
        pla
        jsr PRBYTE
        lda #' '
        jsr pch
        ; cluster inicial (FAT16: so a parte baixa)
        ldy #$1A
        lda (ENT),y
        sta V+vFCL
        iny
        lda (ENT),y
        sta V+vFCL+1
        stz V+vFCL+2
        stz V+vFCL+3
        lda FTYP
        beq @c16
        ldy #$14
        lda (ENT),y
        sta V+vFCL+2
        iny
        lda (ENT),y
        sta V+vFCL+3
@c16:   ldx #vFCL
        jsr pr32
        lda #' '
        jsr pch
        lda V+vFCL
        ora V+vFCL+1
        ora V+vFCL+2
        ora V+vFCL+3
        bne @hasc
        jsr msg
        .byte "VAZIO",0
        jmp CROUT
@hasc:  ldx #vCLUS
        ldy #vFCL
        jsr cpy32
        jsr c2l
        ldx #vLBA
        jsr pr32
        ; tamanho multiplo de 512?
        lda V+vFSZ
        bne @irr
        lda V+vFSZ+1
        and #1
        beq @cont
@irr:   jsr msg
        .byte " TAM?",0
@cont:  ; ---- confere contiguidade: cada cluster aponta para o seguinte
        stz FRAG
        ldx #vNCL
        jsr zero32
        ldx #vCLUS
        ldy #vFCL
        jsr cpy32
@slow:  lda KBD                 ; ESC interrompe
        cmp #$9B
        bne @s1
        jmp @esc
@s1:    jsr fatnext             ; NXT = FAT[CLUS]; PTR -> entrada de CLUS no buffer
        php
        ldx #vNCL
        jsr inc32
        plp
        bcc @s2
        jmp @end
@s2:    ldx #vT2
        ldy #vCLUS
        jsr cpy32
        jsr inc32               ; T2 = CLUS+1
        ldy #vNXT
        jsr cmp32
        beq @tofast
        lda #1
        sta FRAG
        ldx #vCLUS
        ldy #vNXT
        jsr cpy32
        bra @slow
@tofast: ldx #vT2               ; atual = NXT; T2 = esperado = atual+1
        ldy #vNXT
        jsr cpy32
        jsr inc32
; laco rapido: enquanto a proxima entrada do mesmo setor de FAT valer "atual+1"
@fast:  clc
        lda PTR
        adc ESZ
        sta PTR
        bcc @f1
        inc PTR+1
        lda PTR+1
        cmp #>(FATB+512)
        beq @tosl               ; acabou o setor: volta ao caminho lento
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
@m:     ldx #vNCL
        jsr inc32
        ldx #vT2
        jsr inc32
        bra @fast
@tosl:  ldx #vCLUS              ; CLUS = T2-1 (cluster cuja entrada estamos olhando)
        ldy #vT2
        jsr cpy32
        jsr dec32
        jmp @slow
@esc:   sta KBDSTRB
        jsr msg
        .byte " (ESC)",0
        jmp CROUT
@end:   jsr msg
        .byte " CL ",0
        ldx #vNCL
        jsr pr32
        lda FRAG
        bne @fr
        jsr msg
        .byte " OK",0
        jmp CROUT
@fr:    jsr msg
        .byte " FRAGMENTADO",0
        jmp CROUT

; ============================================================================
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

; ============================================================================
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

ioerr:  ldx SAVSP               ; volta ao nivel do inicio e encerra
        txs
        jsr msg
        .byte "ERRO DE LEITURA LBA ",0
        ldx #vLBA
        jsr pr32
        jsr msg
        .byte " ST=",0
        lda STATUS
        jsr PRBYTE
        jsr msg
        .byte " ER=",0
        lda ERRREG
        jsr PRBYTE
        jmp CROUT

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
