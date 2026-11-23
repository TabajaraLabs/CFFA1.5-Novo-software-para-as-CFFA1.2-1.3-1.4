; Program to test/exercise the ProDOS CF/IDE driver
; This program simply writes whatever data is found at $3000..$31FF to the
; CF/drive via ProDOS MLI and reads it back from the CF/drive into location
; $4000..$41FF, it then checks to see if the data written matches the
; data read.
;
; To build, use the following commands:
;
; ca65 -t apple2 --cpu 6502 idetest6502.s
; ld65 -t apple2 idetest6502.o -o idetest6502
;
; Tools used to build: CC65 6502 Cross C compiler & Assembler
; available at: http://www.cc65.org/

DRIVE_UNIT_NUMBER  =   $70       ;Slot * 16, set to corresponding location of the interface card

;Apple II ROM routine locations:
out            = $fded
KeyBoardInput  = $C000
KeyBoardStrobe = $C010

;Misc Zero page locations
messlo         = $16
messhi         = $17

;ProDOS MLI hook
PRODOS_MLI     =   $BF00

;ProDOS MLI Commands
PRODOS_READ    =   $80
PRODOS_WRITE   =   $81

WriteBuffer    =   $3000
ReadBuffer     =   $4000

   .org $2000

   lda KeyBoardStrobe              ;clear any pending key press
   jsr print
   .byte "THIS PROGRAM WILL TEST AN IDE HARD DRIVE IN SLOT 7. "
   .byte "IT WILL OVERWRITE THE FIRST 32MB WITH TEST PATTERN DATA."
   .byte "THIS TEST WILL OVERWRITE ANY MBR ON THE DRIVE. ", $0D
   .byte "DO YOU WISH TO CONTINUE? (Y=YES, ANYTHING ELSE=NO)",$0D, $00

waitforkey:
   lda KeyBoardInput
   bpl waitforkey                        ;pressing any key quits
   lda KeyBoardInput
   sta KeyBoardStrobe
   and #$7F
   cmp #'Y'
   beq StartTest

   clc
   rts

StartTest:
   lda #0
   sta BlockNumber
   lda #0
   sta BlockNumber+1

LOOP:
   jsr print
   .byte "BLOCK:",$00

;
; Clear out the data area where the data will be read back into
;
   ldx #0
fill_loop:
   lda #0
   sta WriteBuffer,x
   sta WriteBuffer+$100,x
   inx
   bne fill_loop
;
; Set up the ProDOS MLI data structures
;
   lda BlockNumber+1
   sta WriteCommandParms+5
   jsr DSByte

   lda BlockNumber
   sta WriteCommandParms+4
   jsr DSByte

   jsr print
   .byte "  WRITING...",$00

   jsr PRODOS_MLI                  ; call ProDOS to write the data
   .byte  PRODOS_WRITE
   .word  WriteCommandParms

   bcc OK
   pha
   jsr print
   .byte "PRODOS WRITE ERROR:",$00
   pla
   jsr DSByte
   rts


OK:
;
; Read the Data back from the drive
;
   lda BlockNumber+1
   sta ReadCommandParms+5
   lda BlockNumber
   sta ReadCommandParms+4

   jsr print
   .byte "  READING...",$0D,$00

   jsr PRODOS_MLI
   .byte  PRODOS_READ
   .word  ReadCommandParms

   bcc OK2
   pha
   jsr print
   .byte "PRODOS READ ERROR:",$00
   pla
   jsr DSByte
   rts

OK2:

   ldx #0
   stx saveaddrhigh
chkloop:
   stx saveaddrlow
   lda WriteBuffer,x
   cmp ReadBuffer,x
   bne Failed
   inx
   bne chkloop

   ldx #1
   stx saveaddrhigh
   ldx #0
chkloop1:
   stx saveaddrlow
   lda WriteBuffer+$100,x
   cmp ReadBuffer+$100,x
   bne Failed
   inx
   bne chkloop1

   jsr print
   .byte "BLOCK CHECKED: OK!:", $0D, $00

   clc
   lda BlockNumber
   adc #1
   sta BlockNumber
   lda BlockNumber+1
   adc #0
   sta BlockNumber+1

   lda BlockNumber
   cmp #$FF
   bne CheckKey
   lda BlockNumber+1
   cmp #$FF
   beq Exit

CheckKey:
   lda KeyBoardInput
   bmi Exit                        ;pressing any key quits
   jmp LOOP

Exit:
   lda KeyBoardStrobe
   clc
   rts

Failed:
   jsr print
   .byte " DATA FAILED AT:", $00
   lda saveaddrhigh
   jsr DSByte
   lda saveaddrlow
   jsr DSByte
   sec
   rts

print:
   pla
   clc
   adc  #$01
   sta  messlo
   pla
   adc  #00
   sta  messhi
   ldy  #$00
top3:
   lda  (messlo),y
   beq  end
   ora  #$80
   jsr  out
   inc  messlo
   bne  top3
   inc  messhi
   jmp  top3
end:
   lda  messhi
   pha
   lda  messlo
   pha
   rts

DSByte:
	pha
	lsr
	lsr
	lsr
	lsr
	tay
	lda	DSBTable,y
   ora #$80
	jsr	out
	pla
	pha
	and	#$F
	tay
	lda	DSBTable,y
   ora #$80
	jsr	out
	pla
	rts
DSBTable:
	.byte	"0123456789ABCDEF"

saveaddrlow:
   .byte  $00
saveaddrhigh:
   .byte  $00


BlockNumber:
   .word  $0000

WriteCommandParms:
   .byte   $03, DRIVE_UNIT_NUMBER, <WriteBuffer, >WriteBuffer, $00, $00

ReadCommandParms:
   .byte   $03, DRIVE_UNIT_NUMBER, <ReadBuffer, >ReadBuffer, $00, $00
