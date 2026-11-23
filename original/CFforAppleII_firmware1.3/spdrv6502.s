;------------------------------------------------------------------------------
; ProDOS/SmartPort driver for CompactFlash/IDE Interface for Apple II computers
; spdrv6502.s  Version 1.0 - 04/18/2004
;
; Firmware Contributors:        Email:
;  Chris Schumann                cschumann@twp-llc.com
;  Rich Dreher                   rich@dreher.net
;  Dave Lyons                    dlyons@lyons42.com
;
;
; This version only requires a 6502 or later equipped machine.
;
; Tools used to build this driver: CA65: 6502 Cross Assembler
; http://www.cc65.org/
;
; Here is the copyright from that tool using --version option
; ca65 V2.6.9 - (C) Copyright 1998-2000 Ullrich von Bassewitz
;
; Example build instructions on an MSDOS based machine:
;------------------------------------------------------
; Assumes you have installed the CC65 package and set your path, etc.
;
; 1) c:\firmware> ca65 -t apple2 --cpu 6502 -l spdrv6502.s
; 2) c:\firmware> ld65 -t apple2 spdrv6502.o -o spdrv6502.bin
; 3) Because the EPROM can hold up to 8 user selectable version of firmware
;    you must load spdrv6502.bin into your EPROM programmer with one of the
;    following offsets:
;    (Note: this offset has nothing to do with the card slot offsets)
;
;  for driver #0: use offset $0000.  Selected with: A14= IN, A13= IN, A12= IN
;  for driver #1: use offset $1000.  Selected with: A14= IN, A13= IN, A12=OUT
;  for driver #2: use offset $2000.  Selected with: A14= IN, A13=OUT, A12= IN
;  for driver #3: use offset $3000.  Selected with: A14= IN, A13=OUT, A12=OUT
;  for driver #4: use offset $4000.  Selected with: A14=OUT, A13= IN, A12= IN
;  for driver #5: use offset $5000.  Selected with: A14=OUT, A13= IN, A12=OUT
;  for driver #6: use offset $6000.  Selected with: A14=OUT, A13=OUT, A12= IN
;  for driver #7: use offset $7000.  Selected with: A14=OUT, A13=OUT, A12=OUT
;
;  where IN = jumper shorted, and OUT = jumper open
;  Driver #0 through #7 correspond to the user selectable
;  jumpers: J6 (A14,A13,A12) on the interface card.
;
; 4) Load as many firmware versions, up to 8, into the EPROM programmer as you
;    want. Remember that most programmers will, by default, clear all unused
;    memory to $FF when you load a binary file. You will need to disable that
;    feature after loading the first file.
;
; 5) Now you have an EPROM ready image to be programmed.
;    Using a standard 27C256 EPROM or similar, program your EPROM.
;
; Firmware Version History
;-------------------------
;
; Version 1.0:  (6502 version located at EPROM offset $4000, selection #4)
;   - Start of 6502 specific driver. Based on Version 1.2 spdrv.s driver
;   - Now works with 6502 CPU. Removed all 65C02 specific instruction from the ver 1.2 firmware
;   - NOTE: To work in 6502 based machine, logic CPLD version 1.3 or later is required.
;   - Changed error messages to upper case for Apple ]['s that don't support lower case.
;   - Setup slot specific behavior: Slot 5 has smartport enabled but will not autoboot.
;       All other slots have smartport disabled, but will autoboot in an Apple ][+ or ][e.
;   - Made 4th boot signature byte a parameter to boot code macro to ease slot specific setup.
;   - Changed GSOS_DRIVER signature to $10. This will prevent Dave Lyons' GS/OS driver from
;       loading should someone inadvertently using this firmware in a ][GS.
;   - Change offsets for code loading with addition of .RES command
;       bin files can now be loaded in EPROM at normal 4K offsets:$0, $1000, $2000, etc,
;       instead of offsets $100, $1100, $2100, etc.
;
; PLD Logic Firmware Information
;-------------------------------
; This version of firmware assumes you are using PLD logic of at
; least CPLD logic version 1.3.  The source files for U6, the Altera PLD are:
;       Appleideinterface.gdf
;       Appleidelogic.tdf
;
; The programmer ready output file for the PLD logic is:
;       Appleideinterface.pof
;
; These files are not included with this code.
;
; Acknowledgements
;-----------------
;Thanks to:
; Chris Schuman - for his extensive initial development work
; David Lyons   - for technical information, many improvement ideas and
;                 SmartPort code development
;

.define         EQU             =
.define         TRUE            1
.define         FALSE           0


;
; Firmware Version Information
;
FIRMWARE_VER    EQU $10        ;Version 1.0 (Version of this code)
SPDRIVERVERSION EQU $1200      ;SmartPort version 1.2
GSOS_DRIVER     EQU $10        ;GS/OS driver will check this byte to see if it
                                ;is still compatible with this firmware.
                                ;Increment by one, when something changes that
                                ;would require a change in the GS/OS driver.
                                ;Otherwise only change the FIRMWARE_VER for all
                                ;other changes.
                                ;01 = ProDOS Driver supporting 2 drives.
                                ;02 = SmartPort Driver supporting 4 drives
                                ;03 = SmartPort Driver supporting 8 drives.NOTE: GS/OS driver won't load
                                ;10 - 6502 version: ProDOS Driver supporting 2 drives. NOTE: GS/OS driver won't load
;
; Firmware Configuration Settings:
;
SMARTPORT_SIG   EQU FALSE      ;Set to FALSE for booting on ][, ][+ machines who's ROM checks 4 bytes of boot sig.
                               ;    to TRUE for booting on IIe and later machines, that only check 3 bytes of boot sig.

BLOCKOFFSET     EQU 0          ;0..255: LBA of first block of first partition
PARTITIONS32MB  EQU 4          ;Number of 32MB Partitions supported
                               ;Remember, ProDOS only supports 13 total
                               ;volumes for all devices, floppies, SCSI drives,
                               ;RAM drives, etc.
DEBUG  = FALSE
;DEBUG  = TRUE
;------------------------------------------------------------------------------
; To enable debug output, set DEBUG = TRUE, only if you have a Apple Super
; Serial card in slot 2. This will output one line of text for each request
; made to the firmware, which can be seen on a computer or terminal attached to
; the SSC.
;
; NOTE: If you use DEBUG=TRUE and you don't have an Apple Super Serial card in
; slot 2, your computer might hang in the routine DSChar, waiting for
; the SSC status bit to say it is okay to write to the 6551 UART.
;
; Set your terminal (software) at the remote end as follows:
; BaudRate:      19200
; Data Bits:     8
; Parity:        None
; Stop Bits:     1
;
; Example debug output at terminal from CAT command in ProDOS 8. Card is in
; slot 6. ProDOS makes a ProDOS 8 call to the firmware to read block 2 from
; unit: 60 into buffer memory at $DC00.
;
; P8: Rd B:0002 U:60 A$DC00 Chk$6711
;
; Rd = ProDOS Read ($01). Also could be Wr = write ($02), St = Status ($00)
; U:60 = ProDOS 8 unit number $60  Slot 6, drive 1
; A$DC00 = ProDOS buffer address
; Chk$6711 = Simple block checksum used to visually check data integrity
;
; NOTE: When DEBUG is true, some zero-page locations are used. The data at
; these locations are saved and restored and should not impact other programs.


;------------------------------------------------------------------------------
; Driver constant definitions
;
INITDONESIG     EQU $A5           ;Device init is done signature value
CR              EQU $0D
BELL            EQU $07

; ProDOS request Constants
PRODOS_STATUS   EQU $00
PRODOS_READ     EQU $01
PRODOS_WRITE    EQU $02
PRODOS_FORMAT   EQU $03

;ProDOS Return Codes
PRODOS_NO_ERROR      EQU $00    ;No error
PRODOS_BADCMD        EQU $01    ;Bad Command (not implemented)
PRODOS_IO_ERROR      EQU $27    ;I/O error
PRODOS_NO_DEVICE     EQU $28    ;No Device Connected
PRODOS_WRITE_PROTECT EQU $2B    ;Write Protected
PRODOS_BADBLOCK      EQU $2D    ;Invalid block number requested
PRODOS_OFFLINE       EQU $2F    ;Device off-line

;SmartPort return codes
BAD_UNIT_NUMBER EQU $11

; ATA Commands Codes
ATACRead        EQU $20
ATACWrite       EQU $30
ATAIdentify     EQU $EC

;Constants for Wait
; Constant = (Delay[in uS]/2.5 + 2.09)^.5 - 2.7

WAIT_100ms      EQU 197
WAIT_40ms       EQU 124
WAIT_100us      EQU 4
;------------------------------------------------------------------------------
; Slot I/O definitions
;
mslot           = $7F8          ;Apple defined location for the last active slot

IOBase          = $C080
ATADataHigh     = IOBase+0
SetCSMask       = IOBase+1      ;Two special strobe locations to set and clear
                                ; MASK bit that is used to disable CS0 line to
                                ; the CompactFlash during the CPU read cycles
ClearCSMask     = IOBase+2      ; that occur before every CPU write cycle.
                                ; The normally innocuous read cycles were
                                ; causing the SanDisk CF to double increment
                                ; during sector writes commands.

ATADevCtrl      = IOBase+6      ;when writing
ATAAltStatus    = IOBase+6      ;when reading
ATADataLow      = IOBase+8
ATAError        = IOBase+9
ATASectorCnt    = IOBase+10
ATASector       = IOBase+11
ATACylinder     = IOBase+12
ATACylinderH    = IOBase+13
ATAHead         = IOBase+14
ATACommand      = IOBase+15     ; when writing
ATAStatus       = IOBase+15     ; when reading

; Scratchpad RAM base addresses. Access using the Y register containg the slot #
;
DriveResetDone  = $478          ;remember the device has been software reset
DriveNumber     = $4f8          ;normally 0 to 3 for four 32MB partitions
SerialInitDone  = $578          ;For debug: if $A5 then serial init is complete
DrvBlkCount0    = $5f8          ;low byte of usable block count
                                ; (excluding first BLOCKOFFSET blocks)
DrvBlkCount1    = $678          ;bits 8..15 of usable block count
DrvBlkCount2    = $6f8          ;bits 16..23 of usable block count
DrvMiscFlags    = $778          ;bit 7 = raw LBA block access
Available2      = $7f8          ;not currently used

;------------------------------------------------------------------------------
; Zero-page RAM memory usage

.IF DEBUG                       ;data at these locations saved and restored
MsgPointerLow   = $EB
MsgPointerHi    = $EC
CheckSumLow     = $ED
CheckSumHigh    = $EE
.ENDIF

zpt1            = $EF           ;data at this location is saved/restored

StackBase       = $100

; ProDOS block interface locations
pdCommandCode   = $42
pdUnitNumber    = $43
pdIOBuffer      = $44
pdIOBufferH     = $45
pdBlockNumber   = $46
pdBlockNumberH  = $47

; Arbitrary locations for Smartport data,
;  these locations are saved/restored before exit.
spCommandCode   = pdCommandCode

spParamList     = $48           ;2 bytes
spCmdList       = $4A           ;2 bytes
spCSCode        = $4C
spSlot          = $4D
spSlotX16       = $4E
spLastZP        = spSlotX16

spZeroPgArea    = pdCommandCode ; $42
spZeroPgSize    = spLastZP-spZeroPgArea+1


;------------------------------------------------------------------------------
; Apple II ROM entry points
;
; We can use these at boot time, but not while handling a call through
; our ProDOS or SmartPort entry points, as the ROM may not be available.
;
SetVID          = $FE89
SetKBD          = $FE93
COUT            = $FDED
INIT            = $FB2F
HOME            = $FC58
ROMWAIT         = $FCA8
AppleSoft       = $E000

;------------------------------------------------------------------------------
; Start of Peripheral Card ROM Space $Cn00 to $CnFF
; A macro is used here so that this code can be easily duplicated for each slot
; instead of by hand using the EPROM programmer. This is done because
; the hardware does not overlay the C1xx address space at C2xx, C3xx, etc.
; automatically. Instead the base address for the EPROM is $C000 but is enabled
; only when a valid address in the range of $C100 to $CEFF is on the bus. This
; allows for the development of slot specific behaviors in firmware, if desired.
; Currently that is not being done, instead the same slot code is repeated for
; every slot ROM space. Addresses $C000 to $C0FF are not decoded by the
; hardware as it is Apple's internal I/O. Any access of $CF00 to $CFFF is
; decoded by the card to reset the Expansion ROM flip-flop, but remember to
; use always address $CFFF for that task.

.macro  CnXX    SLOTADDR, SLOTx16, SLOT, SIGNATURE_BYTE_4
   .local P8DriverEntry
   .local P8Driver
   .local SmartPortEntry
   .local SPDriver
   .local Boot
   .local Error
   .local NotScanning
   .local wasteTime
   .local ErrorMsgDisplay
   .local msgLoop
   .local msgDone
   .local ErrorMessage

   lda  #$20                    ;$20 is a signature for a drive to ProDOS
   ldx  #$00                    ;$00 "
   lda  #$03                    ;$03 "



   .byte $A9
   .byte SIGNATURE_BYTE_4       ;If this byte has b7 set, the next instruction should be a bmi
   bpl  Boot                    ;NOTE: this must be a 2 byte instuction to keep the entry point offset correct

;------------------- Non-boot P8 driver entry point ---------------------
;  The EPROM holding this code is decoded and mapped into $C100 to $CEFF,
;  it is not nessecary to dynamically determine which slot we are in, as is
;  common in card firmware. This code is in a MACRO and is located absolutely
;  per slot. Any code in this MACRO that is not relocatable will have to be
;  based on the MACROs parameters SLOTADDR, SLOTx16, SLOT.

P8DriverEntry:
   jmp  P8Driver                ;located at $Cn0A for best compatibility
SmartPortEntry:                 ;By definition, SmartPort entry is 3 bytes
                                ; after ProDOS entry
   jmp  SPDriver

Boot:
   ldy  #SLOT                   ;Y reg now has $0n for accessing scratchpad RAM
   ldx  #SLOTx16                ;X reg now has $n0 for indexing I/O
   lda  #>SLOTADDR              ;loads A with slot# we are in:$Cn
   sta  mslot                   ;Apple defined location reserved for last slot
                                ; active. MSLOT needs the form of $Cn
   bit  $cfff                   ;turn off expansion ROMs

;
; Need to wait here (before CheckDevice) in case the CFFA RESET jumper
; is enabled, or a Delkin Devices CF card never becomes ready.
;
   ldy  #5
wasteTime:
   lda  #WAIT_100ms
   jsr  ROMWAIT
   dey
   bne  wasteTime
   ldy  #SLOT

   jsr  CheckDevice
   bcs  Error

   lda  #PRODOS_READ            ;Request: READ block
   sta  pdCommandCode
   lda  #0
   sta  pdIOBuffer              ;Into Location $800
   sta  pdBlockNumber           ;ProDOS block $0000 (the bootloader block)
   sta  pdBlockNumberH
   lda  #$08
   sta  pdIOBufferH
   stx  pdUnitNumber            ;From unit number: $n0 (where n=slot#),
                                ; so drive bit is always 0

   jsr  P8Driver                ;Read bootloader from device's block 0 into
                                ; location $800
   bcs  Error                   ;Check for error during bootblock read

   lda  $800                    ;Check the first byte of boot loader code.
   cmp  #$01                    ;If bootload code is there, this byte = $01
   bne  Error
   lda  $801                    ;If second byte is a 0, it's invalid
                                ; (we'd JMP to a BRK)
   beq  Error

   ldx  pdUnitNumber            ;X should contain the unit number when jumping
                                ; to the bootloader
   jmp  $801                    ;No errors, jump to bootloader just read.


; If any error occured, like drive not present, check to see if we are in a
; boot scan, if so re-enter scan routine, else drop to Applesoft, aborting boot.
Error:
   lda  $00
   bne  NotScanning
   lda  $01
   cmp  mslot
   bne  NotScanning
   jmp  $FABA                   ;Re-enter Monitor's Autoscan Routine

;The boot code must have been called manually because we are not in a slot scan.
NotScanning:
   jsr  SetVID
   jsr  SetKBD
;
;Display error message
;
   jsr  INIT             ;text mode, full screen, page 1
   jsr  HOME
   ldy  #0
msgLoop:
   lda  ErrorMessage,y
   beq  msgDone
   ora  #$80
   jsr  COUT
   iny
   jmp  msgLoop
msgDone:
   jmp  AppleSoft

ErrorMessage:
   .byte CR,CR,CR,CR,CR
   .byte "CFFA: DEVICE MISSING, NOT FORMATTED,",CR
   .byte "OR INCOMPATIBLE.",CR
; "vX.Y" built automatically:
   .byte "VER:",$30+(FIRMWARE_VER/16),".",$30+(FIRMWARE_VER & $F), " FOR 6502."
; Beep, then end-of-message:
   .byte BELL,$00


;------------------- Non-boot entry point for driver code -----------------
;
; Handle a ProDOS call
;
; Setup MSLOT, X and Y registers.
; This must be done every time we enter this driver.
;
P8Driver:
   ldy  #SLOT                   ;Y reg now has $0n for accessing scratchpad RAM
   ldx  #SLOTx16                ;X reg now has $n0 for indexing I/O
   lda  #>SLOTADDR              ;loads A with slot# we are in:$Cn(where n=slot#)
   sta  mslot                   ;Apple defined location reserved for last slot
                                ; active. MSLOT needs the form of $Cn
   bit  $cfff                   ;turn off other ROM that might be on
   sta  ClearCSMask,x           ;reset MASK bit in PLD for normal CS0 signaling
   jmp  P8AuxROM

;--------------------- SmartPort call handler code -----------------------
;
; Called from jmp at $Cn0D.
; 1) Push a block of zero-page locations onto the stack, creating a work space.
; 2) Get the request parameters that follow the call to this driver
; 3) Using request parameters as pointers get request specific information
;    and set up the P8 driver request registers $42-$47.
; 4) Call P8Driver code
; 5) On return from P8Driver code, restore zero page work space, and return to
;    caller.
;
SPDriver:
   lda  #>SLOTADDR
   sta  mslot
   bit  $cfff

   ldx  #SLOTx16                ;X reg now has $n0 for indexing I/O
   sta  ClearCSMask,x           ;reset MASK bit in PLD for normal CS0 signaling
   jmp  SPAuxROM


   .RES   SLOTADDR+$F5-*        ;skip to $CnF5, where n is the slot#

   .byte  GSOS_DRIVER           ;GS/OS driver compatibility byte. GS/OS driver
                                ; checks this byte to see if it is compatible
                                ; with this version of firmware. This way,
                                ; changes to firware versions, that do not
                                ; affect the GS/OS driver will not prevent the
                                ; GS/OS driver from loading and running. This
                                ; byte should be incremented each time a change
                                ; is made that would prevent the GS/OS driver
                                ; from working correctly. I.e. Partition layout
                                ; or something similar.

   .byte "CFFA", FIRMWARE_VER   ;$CnF6..CnFA: Card Hardware ID,
                                ; non-standard scheme

;$CnFB: SmartPort status byte
   .byte $0                     ; Not Extended; not SCSI; not RAM card
                                ; Even if not supporting SmartPort, we need a
                                ; zero at $CnFB so Apple's RAMCard driver
                                ; doesn't mistake us for a "Slinky" memory
                                ; card.

; Data table for ProDOS drive scan
; $CnFC/FD = disk capacity, if zero use status command to determine
   .word $0000                  ;$CnFC-D: A zero here will cause prodos to
                                ; rely on the status command to determine volume size

; $CnFE = status bits (BAP p7-14)
;  7 = medium is removable
;  6 = device is interruptable
;  5-4 = number of volumes (0..3 means 1..4)
;  3 = device supports Format call
;  2 = device can be written to
;  1 = device can be read from (must be 1)
;  0 = device status can be read (must be 1)
   .byte %00010111              ; $CnFE: support 2 ProDOS drives

; $CnFF = LSB of block driver
   .byte <P8DriverEntry         ; $CnFF: low-order offset to ProDOS entry point

.endmacro
;
; Because the base address for this eprom is $C000. NOTE: Although it does NOT
; get enable for addresses in the $C000 to C0FF range, we still need a 1 page
; offset to get the code at the correct location.
;
.RES $100, $FF

;
; Parameters for following macros:
; CnXX SLOTADDR, SLOTx16, SLOT, SIGNATURE_BYTE_4
; A signature byte of $3C is same as Disk ][, and turns smartport support off, and allows autoboot on ][+, ][e.
; A signature byte of $00 signals smartport support, allow 4 drives in slot 5, but disable autoboot on ][+, ][e.

.ORG $C100
   CnXX $C100, $10, $01, $3C         ;Slot PROM code for slot 1. SmartPort disabled. Autoboot.

.ORG $C200
   CnXX $C200, $20, $02, $3C         ;Slot PROM code for slot 2. SmartPort disabled. Autoboot.

.ORG $C300
   CnXX $C300, $30, $03, $3C         ;Slot PROM code for slot 3. SmartPort disabled. Autoboot.

.ORG $C400
   CnXX $C400, $40, $04, $3C         ;Slot PROM code for slot 4. SmartPort disabled. Autoboot.

.ORG $C500
   CnXX $C500, $50, $05, $00         ;Slot PROM code for slot 5. SmartPort enabled. No Autoboot.

.ORG $C600
   CnXX $C600, $60, $06, $3C         ;Slot PROM code for slot 6. SmartPort disabled. Autoboot.

.listbytes      unlimited            ;Show all of the code bytes for the 7th slot
.ORG $C700
   CnXX $C700, $70, $07, $3C         ;Slot PROM code for slot 7. SmartPort disabled. Autoboot.

.listbytes      12              ;revert back to normal listing mode for the rest

;-------------------- End of Peripheral Card ROM Space ----------------------


;--------------------- Start of I/O expansion ROM Space --------------------
; Code here starts at $c800
; This code area is absolute and can use absolute addressing
.ORG   $C800                    ;note: .ORG does not cause this code to be
                                ; placed at C800. The ".RES" statement above
                                ; offsets this code


;------------------------------------------------------------------------------
; SmartPort
;
;------------------------------------------------------------------------------
MagicRawBlocksUnit EQU 127      ;use unit 127 in ReadBlock/WriteBlock calls for
                                ; raw LBA blocks.

SPAuxROM:
; save  ZP, fetch cmd + pointer from (PC)
   ldy  #spZeroPgSize-1
save:
   lda  spZeroPgArea,y
   pha
   dey
   bpl  save
   tsx
   lda  $101+spZeroPgSize,x
   sta  spParamList
   clc
   adc  #3
   sta  $101+spZeroPgSize,x
   lda  $102+spZeroPgSize,x
   sta  spParamList+1
   adc  #0
   sta  $102+spZeroPgSize,x

; set up spSlot and spSlotX16
   lda  mslot
   and  #$0f
   tay
   asl  a
   asl  a
   asl  a
   asl  a
   tax
   sty  spSlot
   stx  spSlotX16

; clear DrvMiscFlags
   lda  #0
   sta  DrvMiscFlags,y          ;no special flags (such as raw block access)

; reset the device if this is our first call
   jsr  ResetDriveIfFirstTime   ;needs Y

.IF DEBUG
;warning this debug code trashes the Acc register
   jsr  DSString
   .byte "SP:",0
.ENDIF

; get command code from parameter list
   ldy  #1
   lda  (spParamList),y
   sta  spCommandCode
   iny
   lda  (spParamList),y
   tax
   iny
   lda  (spParamList),y
   sta  spParamList+1
   stx  spParamList

   lda  #PRODOS_BADCMD          ;anticipate bad command error
   ldx  spCommandCode
   cpx  #$09+1                  ;command too large
   bcs  out

   ldy  #0
   lda  (spParamList),y         ;parameter count
   cmp  RequiredParamCounts,x   ;command number still in X
   beq  pCountOK

   lda  #$04                    ;bad parameter count error
   jmp  out

pCountOK:
   ldy  #1
   lda  (spParamList),y
   ldy  spSlot
   sta  DriveNumber,y

   txa                            ;X is still the command code
   asl  a
   tax
   jsr  JumpToSPCommand           ;Y is still spSlot

   bcs  out
   lda  #0

out:
   tax                           ;error code in X

; Restore zero page
   ldy  #0
restore:
   pla
   sta  spZeroPgArea,y
   iny
   cpy  #spZeroPgSize
   bcc  restore

   txa
   ldy  #2                      ;high byte of # bytes transferred
                                ; (always (1) undefined, or
                                ; (2) #bytes transferred to host)
   ldx  #0                      ;low byte of # bytes transferred
   cmp  #1                      ;C=1 if error code nonzero
   rts

JumpToSPCommand:
   lda  spDispatch+1,x
   pha
   lda  spDispatch,x
   pha
   rts

RequiredParamCounts:
   .byte 3   ;0 = status
   .byte 3   ;1 = read
   .byte 3   ;2 = write
   .byte 1   ;3 = format
   .byte 3   ;4 = control
   .byte 1   ;5 = init
   .byte 1   ;6 = open
   .byte 1   ;7 = close
   .byte 4   ;8 = read
   .byte 4   ;9 = write

spDispatch:
   .word spStatus-1
   .word spReadBlock-1
   .word spWriteBlock-1
   .word spFormat-1
   .word spControl-1
   .word spInit-1
   .word spOpen-1
   .word spClose-1
   .word spReadChars-1
   .word spWriteChars-1

;------------------------------------------------------------------------------
; SmartPort STATUS call
;
; We support the standard calls, plus an "Identify" command
; for unit 0, which fills a buffer with the card's Identify
; data.
;
spStatus:
   jsr  SPSetupControlOrStatus
   bcs  statOut

   ldy  spSlot
   lda  DriveNumber,y
   bne  StatusForOneUnit

; StatusCode = 0 && unit == 0: status for this entire SmartPort interface
   lda  spCSCode
   beq  Status00

; Status for unit 0, subcode $49 = Identify (device-specific subcode)
   cmp  #$49
   bne  BadStatusCode
   jmp  spStatusIdentify

; Any other status code for unit 0 is an error.
BadStatusCode:
   lda  #$21
   sec
   rts

Status00:
   ldx  spSlotX16
   ldy  spSlot
   jsr  GetStatus
   bcs  statOut

   ldy  spSlot
   lda  DrvBlkCount2,y
   clc
   adc  #1
   ldy  #0
   sta  (spCmdList),y           ;byte +0 = number of drives

   ldy  #7
Stat00Loop:
   lda  Stat00Data-1,y
   sta  (spCmdList),y
   dey
   bne  Stat00Loop
   clc
statOut:
   rts

Stat00Data:
   .byte $40                    ;Interrupt flag = no interrupts caused by this
                                ; interface

   .word $CC00                  ;Vendor ID assigned to Rich Dreher by
                                ; www.syndicomm.com 3/16/2002

   .word SPDRIVERVERSION        ;Our version number
   .byte $00                    ;Reserved byte
   .byte $00                    ;Reserved byte

StatusForOneUnit:
   clc
   sbc  #1
   sta  DriveNumber,y

   ldx  spCSCode
   beq  Status0or3
   dex
   beq  StatusGetDCB
   dex
   dex
   beq  Status0or3
   lda  #$21                    ;Bad status code
   sec
   rts
;
; We have no interesting data to return for the device control
; block, so return the shortest one allowed: a length byte of
; 1 followed by a data byte of 0.
;
StatusGetDCB:
   lda  #1
   ldy  #0
   sta  (spCmdList),y           ;Returned length = 1
   tay
   lda  #0
   sta  (spCmdList),y           ;Returned data = $00
   clc
   rts

;
; Status code 0 and 3 start off the same; 3 returns extra data.
;
; 0: return device status (1 byte device status + 3-byte block count)
; 3: return Device Information Block
;
Status0or3:
   lda  #$F8                    ;Block device, write, read, format, online,
                                ; not write-prot
   ldy  #0
   sta  (spCmdList),y
   ldx  spSlotX16
   ldy  spSlot
   jsr  GetStatus               ;Returns block count in YX
   bcs  statOut

   tya
   ldy  #2
   sta  (spCmdList),y           ;CmdList +2 = bits 8..15 of block count
   dey
   txa                          ;CmdList +1 = bits 0..7 of block count
   sta  (spCmdList),y
   ldy  #3
   lda  #0
   sta  (spCmdList),y           ;CmdList +3 = bits 16..23 of block count

   lda  spCSCode
   beq  statDone

; status code 3: return 21 more bytes of data
   ldy #4
stat3Loop:
   lda  stat3Data-4,y
   sta  (spCmdList),y
   iny
   cpy  #21+4
   bcc  stat3Loop

statDone:
   clc
   rts

stat3Data:
   .byte 13,"COMPACT FLASH   "  ;length byte + 16-byte ASCII, padded
   .byte $02                    ;device type = hard disk
   .byte $20                    ;subtype (no removable media, no extended,
                                ; no disk switched)
   .word SPDRIVERVERSION

;------------------------------------------------------------------------------
; Identify (Status subcode)
;
; The status list is a 512-byte buffer that we will fill with
; the drive's IDE "Identify" data.  We post-process the data
; by byte-swapping the model name and serial number strings
; so they make sense.
;
spStatusIdentify:
   ldy  spSlot
   ldx  spSlotX16
   jsr  CheckDevice
   bcc  ident1
   lda  #PRODOS_NO_DEVICE
   rts                          ;return error code in Acc with Carry set

ident1:
   lda  #0
   sta  ATADataHigh,x

   lda  #ATAIdentify
   sta  ATACommand,x            ;Issue the read command to the drive
   jsr  IDEWaitReady            ;Wait for BUSY flag to go away

   lda  ATAStatus,x             ;Check for error response
   and  #$09
   cmp  #$01                    ;if DRQ=0 and ERR=1 an error occured
   bne  iCommandOK

iError:
.IF DEBUG
;warning this debug code trashes the Acc register
   jsr DSString
   .byte "spIdfy Err:",0
   lda  ATAError,x
   jsr  DSByteCRLF
.ENDIF

   lda  #PRODOS_IO_ERROR
   sec
   rts                          ;return error code in Acc with Carry set
;
; The "Identify" data is ready to read
;
pageCount = spCommandCode       ;re-use a zero-page location

iCommandOK:
   ldy  #2
   sty  pageCount
   ldy  #0
iLoop:
   lda  ATAStatus,x             ;Note: not using IDEWaitReady, inline code
                                ; instead
   bmi  iLoop                   ;Wait for BUSY (bit 7) to be zero
   and  #$08                    ;get DRQ status bit
   beq  iError                  ;if off, didn't get enough data

   lda  ATADataLow,x
   sta  (spCmdList),y
   iny
   lda  ATADataHigh,x
   sta  (spCmdList),y
   iny
   bne  iLoop
   inc  spCmdList+1
   dec  pageCount
   bne  iLoop

; Swap ASCII text data of the Identify data to be more readable.
; These are both on the first page of the data.

   dec  spCmdList+1
   dec  spCmdList+1             ;Point to beginning of buffer

   ldy  #23*2                   ;Start at word 23 (firmware rev, model number)
   ldx  #24                     ;24 words
   jsr  SwapBytes

   ldy  #10*2                   ;Start at word 10 (serial number)
   ldx  #10                     ;10 words
   jsr  SwapBytes

   clc
   rts

;------------------------------------------------------------------------------
SwapBytes:
   lda  (spCmdList),y
   pha                          ;Save the 1st byte
   iny
   lda  (spCmdList),y           ;Get the 2nd byte
   dey
   sta  (spCmdList),y           ;Store it in position 1
   iny
   pla                          ;Finally, retrieve the 1st byte
   sta  (spCmdList),y           ;Put it in position 2
   iny
   dex
   bne  SwapBytes
   rts

;------------------------------------------------------------------------------
; SmartPort READ BLOCK command
;
spReadBlock:
   jsr  SPSetupReadWrite
   bcs  readDone

   ldy  spSlot
   ldx  spSlotX16
   jmp  ReadBlock

readDone:
writeDone:
   rts

;------------------------------------------------------------------------------
; SmartPort WRITE BLOCK command
;
spWriteBlock:
   jsr SPSetupReadWrite
   bcs writeDone

   ldy spSlot
   ldx spSlotX16
   jmp WriteBlock

;------------------------------------------------------------------------------
; SmartPort FORMAT command
;
; We don't actually do anything beyond validating the unit number.
;
spFormat:
   jmp SPValidateUnitNumber

;------------------------------------------------------------------------------
; SmartPort CONTROL command
;
spControl:
   jsr SPSetupControlOrStatus
   bcs ctrlDone

   jsr SPValidateUnitNumber
   bcs ctrlDone

   ldx spCSCode
   beq ctlReset                 ;Control code 0 = Reset
   dex
   beq ctlSetDCB                ;Control code 1 = SetDCB
   dex
   beq ctlSetNewline            ;Control code 2 = SetNewline
   dex
   beq ctlServiceInterrupt      ;Control code 3 = ServiceInterrupt
   dex
   beq ctlEject                 ;Control code 4 = Eject

ctlSetNewline:
   lda #$21                     ;Bad control code
   sec
ctrlDone:
   rts

ctlServiceInterrupt:
   lda #$1f                     ;Interrupt devices not supported
   sec
   rts

ctlReset:
ctlSetDCB:
ctlEject:
   clc
   rts

;------------------------------------------------------------------------------
; SmartPort INIT command
;
; unit 0 = entire chain
;
;  SmartPort Technote #2 says you can't init an individual unit;
;  so return error if DriveNumber is nonzero.
;
spInit:
   lda DriveNumber,y
   beq initChain
   lda #BAD_UNIT_NUMBER
   sec
   rts

initChain:
   clc
   rts


;------------------------------------------------------------------------------
; SmartPort: Open and Close are for character devices only
;
spOpen:
spClose:
   lda #PRODOS_BADCMD
   sec
   rts

;------------------------------------------------------------------------------
; SmartPort: Read, Write
;
; We don't bother implementing Read and Write, although they are allowed
; for block devices.  We would only support 512-byte transfers anyway.
;
spReadChars:
spWriteChars:
   lda #PRODOS_IO_ERROR
   sec
   rts


;------------------------------------------------------------------------------
; SPSetupControlOrStatus
;
; fetch from parameter block:
;    status/control list pointer (word)
;    status/control code (byte)
;
SPSetupControlOrStatus:
   ldy #2
   lda (spParamList),y
   sta spCmdList
   iny
   lda (spParamList),y
   sta spCmdList+1
   iny
   lda (spParamList),y
   sta spCSCode
   clc
   rts

;------------------------------------------------------------------------------
; SPSetupReadWrite
;
; Input:
;    DriveNumber,y is already a copy of SmartPort unit number
;
; fetch from SP parameter list:
;   buffer pointer
;   block number
;
; Validate unit number:
;   127 = magic, allow any block number
;   1..N:  Validate block number: $0..FFFE
;
; DriveNumber,y: translated unit number in case unit was magic
; DrvMiscFlags: bit 7 set if we should not use BLOCKOFFSET
;
SPSetupReadWrite:
; copy pdIOBuffer from parameter list
   ldy #2
   lda (spParamList),y
   sta pdIOBuffer
   iny
   lda (spParamList),y
   sta pdIOBuffer+1

; copy pdBlockNumber from parameter list
   iny
   lda (spParamList),y
   sta pdBlockNumber
   iny
   lda (spParamList),y
   sta pdBlockNumber+1

; Validate the unit number and block number.
   ldy spSlot
   lda DriveNumber,y
   cmp #MagicRawBlocksUnit
   beq magicUnit

   jsr SPValidateUnitNumber
   bcs srwOut

   ldy #6
   lda (spParamList),y          ;Bits 16..23 of block number must be $00
   bne badBlockNum

   lda pdBlockNumber+1          ;Block $FFFF is invalid
   and pdBlockNumber
   clc
   adc #1
   beq badBlockNum
   clc
   rts

badBlockNum:
   lda #PRODOS_BADBLOCK         ;Bad block number
   sec
srwOut:
   rts
;
; For the "magic raw blocks" unit, allow a full 3-byte block number.
;
magicUnit:
   lda #$80
   ora DrvMiscFlags,y
   sta DrvMiscFlags,y           ;Raw block access

   ldy #6
   lda (spParamList),y          ;Bits 16..23 of block number
   ldy spSlot
   sta DriveNumber,y
   clc
   rts

;------------------------------------------------------------------------------
; SPValidateUnitNumber
;
; Validate that DriveNumber is from 1 to N.
;
; Input: DriveNumber
;
; Output: DriveNumber in range 0..N-1
;
SPValidateUnitNumber:
   ldy spSlot
   lda DriveNumber,y
   beq badUnit
   clc
   sbc  #1
   sta DriveNumber,y
   cmp DrvBlkCount2,y
   beq unitOK
   bcs badUnit
unitOK:
   clc
   rts

badUnit:
   lda #BAD_UNIT_NUMBER
   sec
   rts

;------------------------------------------------------------------------------
; P8AuxROM - Handle a ProDOS call
;
P8AuxROM:

; If the ProDOS unit number doesn't match our slot number, add 2 to
; the drive number.
;
; This actually happens: If we're in slot 5, we get calls for slot 2
; that want to access our 3rd and 4th partitions.
   txa                          ; A = $n0
   eor  pdUnitNumber
   and  #$70                    ;EOR the slot number
   beq  OurSlot
   lda  #2                      ;Point to drive 3 or 4

OurSlot:
   bit  pdUnitNumber
   bpl  DriveOne
   clc
   adc  #1

DriveOne:
   sta  DriveNumber,y
   lda  #0
   sta  DrvMiscFlags,y          ;no special flags (such as raw block access)

   jsr  ResetDriveIfFirstTime

; process the command code and jump to appropriate routine.

.IF DEBUG
;warning this debug code trashes the Acc register
   jsr  DSString
   .byte "P8:",0
.ENDIF

   lda  pdCommandCode
   cmp  #PRODOS_READ
   bne  chk1
   jmp  ReadBlock

chk1:
   cmp  #PRODOS_WRITE
   bne  chk2
   jmp  WriteBlock

chk2:
   cmp  #PRODOS_STATUS
   bne  chk3
   jmp  GetStatus

chk3:
; An invalid request # has been sent to this driver.
;
.IF DEBUG
   pha
   jsr DSString
   .byte "CE",0
   pla
   jsr  DSByteCRLF
.ENDIF

   lda  #PRODOS_IO_ERROR
   sec
   rts                             ;return to caller. Should always be ProDOS

;------------------------------------------------------------------------------
; ResetDriveIfFirstTime - Reset the drive once, the first time the driver
; is called ide_devctrl Bit 2 = Software Reset, Bit 1 = nIEN (enable
; assertion of INTRQ)
;
; Input:
;       X = requested slot number in form $n0 where n = slot 1 to 7
;       Y = $0n (n = slot#) for accessing scratchpad RAM;
;
; ZeroPage Usage:
;       None
;
; CPU Registers changed:  A, P
;
ResetDriveIfFirstTime:
   lda  DriveResetDone,Y
   cmp  #INITDONESIG
   beq  resetOK
;
; Reset the ATA device
;
   lda  #0
   sta  ATADataHigh,x           ;Clear high byte data latch

   lda  #$06                    ;Reset bit=1, Disable INTRQ=1
   sta  ATADevCtrl,x
;
; Per ATA-6 spec, need to wait 5us minimum. Use a delay of 100us.
; Should cover accelerated Apples up to 20Mhz.
;
   lda  #WAIT_100us
   jsr  Wait

   lda  #$02                    ;Reset bit=0, Disable INTRQ=1
   sta  ATADevCtrl,x
;
; Per ATA-6 spec, need to wait 2ms minimum. Use a delay of 40ms.
; Should cover accelerated Apples up to 20Mhz.
;
   lda  #WAIT_40ms
   jsr  Wait
;
; Per ATA-6 spec, wait for busy to clear, by calling IDEWaitReady
;
   jsr  IDEWaitReady

   lda  #INITDONESIG
   sta  DriveResetDone,Y        ;Set the init done flag so init only happens
                                ; once.
resetOK:
   rts

;------------------------------------------------------------------------------
; GetStatus - Called by ProDOS and SmartPort to get device status and size
;
; Input:
;       DriveNumber,y (0 to 3)
;       X = slot number in form $n0 where n = slot 1 to 7
;       Y = $0n (n = slot#) for accessing scratchpad RAM;
;
; Output:
;       A = ProDOS status return code
;       X = drive size LSB
;       Y = drive size MSB
;       Carry flag: 0 = Okay, 1 = Error
;       DrvBlkCount0..DrvBlkCount2 = usable blocks on device
;
GetStatus:

.IF DEBUG
;warning this debug code trashes the Acc register
   jsr  DSString
   .byte " St",0
   jsr  DisplayParms
.ENDIF

;
; Determine if a drive/device is present.
;
   jsr  CheckDevice
   bcc  sDriveOK

   ldx  #$00
   ldy  #$00
   lda  #PRODOS_OFFLINE
   sec
   jmp  sExit

; Device is present
sDriveOK:
   lda  #0
   sta  ATADataHigh,x           ;clear high byte transfer latch

   jsr  IDEWaitReady
   lda  #ATAIdentify
   sta  ATACommand,x            ;Issue the read command to the drive
   jsr  IDEWaitReady            ;Wait for BUSY flag to go away

   lda  ATAStatus,x             ;Check for error response
   and  #$09
   cmp  #$01                     ;if DRQ=0 and ERR=1 an error occured
   bne  sValidATACommand

.IF DEBUG
;warning this debug code trashes the Acc register
   jsr DSString
   .byte " Idfy Err:",0
   lda  ATAError,x
   jsr  DSByteCRLF
.ENDIF

   ldx  #0
   ldy  #0
   lda  #PRODOS_IO_ERROR
   sec
   jmp  sExit                   ; Command Error occured, return error

sValidATACommand:
   tya
   pha                          ;save Y, it holds the $0n sratchpad RAM offset
   ldy  #$00                    ;zero loop counter

sPrefetchloop:
   jsr  IDEWaitReady            ;See if a word is ready
   bcs  sWordRdy
   pla
   tay
   lda  #PRODOS_IO_ERROR
   jmp  sExit

sWordRdy:
   lda  ATADataLow,x            ;Read words 0 thru 56 but throw them away
   iny
   cpy  #57                     ;Number of the last word you want to throw away
   bne  sPrefetchloop
   pla
   tay

sPrefetchDone:
   lda  ATADataLow,x            ;Read the current capacity in sectors (LBA)
   sec
   sbc  #BLOCKOFFSET
   sta  DrvBlkCount0,y
   lda  ATADataHigh,x
   sbc  #0
   sta  DrvBlkCount1,y
   lda  ATADataLow,x
   sbc  #0
   sta  DrvBlkCount2,y


.IF DEBUG
   jsr  DSString
   .byte "Size:",0

   lda  ATADataHigh,x           ;get the high byte of high word just for display
   jsr  DSByte
   lda  DrvBlkCount2,y
   jsr  DSByte
   lda  DrvBlkCount1,y
   jsr  DSByte
   lda  DrvBlkCount0,y
   jsr  DSByte
   jsr  DSBlank
.ENDIF

   lda  DrvBlkCount2,y
   cmp  #PARTITIONS32MB         ;max out at (#PARTITIONS32MB * $10000 + 00FFFF)
                                ; blocks
   bcs  maxOutAtN

   lda  ATADataHigh,x
   beq  lessThan8GB
maxOutAtN:
   lda  #$FF                    ;The device is truly huge! Just set our 3-byte
                                ; block count to $03FFFF
   sta  DrvBlkCount0,y
   sta  DrvBlkCount1,y
   lda  #PARTITIONS32MB-1       ;Number of 32MB devices, set by the equate:
                                ; #PARTITIONS32MB
   sta  DrvBlkCount2,y
lessThan8GB:


PostFetch:
   jsr IDEWaitReady             ;read the rest of the words, until command ends
   bcc sReadComplete
   lda ATADataLow,x
   jmp PostFetch
sReadComplete:

; DrvBlkCount2 is the number of 32 MB partitions availiable - 1,
; or the highest drive # supported (zero based).
;
; If DrvBlkCount2 > drive # then StatusSize = $FFFF
; If DrvBlkCount2 = drive # then StatusSize = DrvBlkCount1,DrvBlkCount0
; If DrvBlkCount2 < drive # then StatusSize = 0
;
; This scheme has a special case which must be handled because ProDOS
;   partitions are not quite 32 meg in size but are only FFFF blocks in size.
;   If a device is exactly: 32meg or 10000h blocks in size, it would appear
;   as one drive of size FFFF and another drive of size 0000. To handle this
;   case, we check for an exact size of 0000 and fall into the NoDrive code.
;
   lda DriveNumber,y
   cmp DrvBlkCount2,y
   beq ExactSize
   bcc FullSize

NoDrive:
   ldx  #0
   ldy  #0
   lda  #PRODOS_OFFLINE
   sec
   jmp  sExit

ExactSize:                    ;If equal, the DrvBlkCount1,DrvBlkCount0 is the
                              ; drive's exact size
   lda  DrvBlkCount0,y
   ora  DrvBlkCount1,y
   beq  NoDrive               ;can't have a 0-block device

   lda  DrvBlkCount0,y
   tax
   lda  DrvBlkCount1,y
   tay
   lda  #0
   clc                          ;no errors
   jmp  sExit

FullSize:
   ldx  #$FF                    ;X gets low byte of size
   ldy  #$FF                    ;Y gets high byte of size
   lda  #0
   clc                          ;no errors

sExit:
.IF DEBUG
   php                          ;save the carry's state
   pha                          ;save the accumulator
   jsr  DSString
   .byte "Retd:",0
   tya
   jsr  DSByte
   txa
   jsr  DSByteCRLF
   pla
   plp                          ;recover the carry
.ENDIF

   rts

;------------------------------------------------------------------------------
; ReadBlock - Read a block from device into memory
;
; Input:
;       pd Command Block Data $42 - $47
;       X = requested slot number in form $n0 where n = slot 1 to 7
;
; Output:
;       A = ProDOS read return code
;       Carry flag: 0 = Okay, 1 = Error
;
; ZeroPage Usage:
;       $EF
;       w/DEBUG enabled: $EB, $EC, $ED, $EE
;       Note: location $EF is saved and restored before driver exits
;
ReadBlock:
.IF DEBUG
   jsr  DSString
   .byte " Rd",0
   jsr  DisplayParms
.ENDIF

   lda  pdIOBufferH
   pha
   lda  zpt1
   pha

.IF DEBUG
   lda  CheckSumHigh
   pha
   lda  CheckSumLow
   pha
.ENDIF

   jsr ReadBlockCore
   tax                              ; ver1.3: Save Acc

.IF DEBUG
   pla
   sta  CheckSumLow
   pla
   sta  CheckSumHigh
.ENDIF

   pla
   sta  zpt1
   pla
   sta  pdIOBufferH
   txa                              ; ver1.3: restore Acc
   rts

ReadBlockCore:
.IF DEBUG
   lda  #0
   sta  CheckSumLow
   sta  CheckSumHigh
.ENDIF

   jsr  IDEWaitReady
   jsr  Block2LBA               ;Program the device's task file registers
                                ; based on ProDOS address

   lda  #0
   sta  ATADataHigh,x

   lda  #ATACRead
   sta  ATACommand,x            ;Issue the read command to the drive
   jsr  IDEWaitReady            ;Wait for BUSY flag to clear

   lda  ATAStatus,x             ;Check for error response from device
   and  #$09
   cmp  #$01                    ;If DRQ=0 and ERR=1 a device error occured
   bne  rCommandOK

.IF DEBUG
;warning this debug code trashes the Acc register
   jsr DSString
   .byte " Err!",0
   lda  ATAError,x
   jsr  DSByteCRLF
.ENDIF

;
; The drive has returned an error code. Just return I/O error code to PRODOS
;
   lda  #PRODOS_IO_ERROR
   sec
   rts
;
; Sector is ready to read
;
rCommandOK:
   ldy  #2
   sty  zpt1
   ldy  #0

rLoop:
   lda  ATAStatus,x             ;Note: not using IDEWaitReady, using inline code
   bmi  rLoop                   ;Wait for BUSY (bit 7) to be zero
   and  #$08                    ;get DRQ status bit
   beq  rShort                  ;if off, didn't get enough data

   lda  ATADataLow,x
   sta  (pdIOBuffer),y
   iny

.IF DEBUG
   clc
   adc  CheckSumLow
   sta  CheckSumLow
.ENDIF

   lda  ATADataHigh,x
   sta  (pdIOBuffer),y

.IF DEBUG
   adc CheckSumHigh
   sta CheckSumHigh
.ENDIF

   iny
   bne  rLoop
   inc  pdIOBufferH
   dec  zpt1
   bne  rLoop

.IF DEBUG
   jsr  DSString
   .byte " Chk$",0

   lda  CheckSumHigh
   jsr  DSByte
   lda  CheckSumLow
   jsr  DSByteCRLF
.ENDIF

   lda  #0
   clc
   rts
;
; The Block was short, return I/O error code to PRODOS
;
rShort:
.IF DEBUG
   jsr  DSString
   .byte " Short blk", 0

   lda  zpt1
   jsr  DSByte
   tya
   jsr  DSByteCRLF
.ENDIF

   lda #PRODOS_IO_ERROR
   sec
   rts

;------------------------------------------------------------------------
; WriteBlock - Write a block in memory to device
;
; Input:
;       pd Command Block Data $42 - $47
;       X = requested slot number in form $n0 where n = slot 1 to 7
;
; Output:
;       A = ProDOS write return code
;       Carry flag: 0 = Okay, 1 = Error
;
; ZeroPage Usage:
;       $EF
;       w/DEBUG enabled: $EB, $EC, $ED, $EE
;       Note: location $EF is saved and restored before driver exits
;
WriteBlock:
.IF DEBUG
   jsr  DSString
   .byte " Wt",0
   jsr  DisplayParms
.ENDIF

   lda  pdIOBufferH
   pha
   lda  zpt1
   pha

.IF DEBUG
   lda  CheckSumHigh
   pha
   lda  CheckSumLow
   pha
.ENDIF

   jsr  WriteBlockCore
   tax
.IF DEBUG
   pla
   sta  CheckSumLow
   pla
   sta  CheckSumHigh
.ENDIF

   pla
   sta  zpt1
   pla
   sta  pdIOBufferH
   txa
   rts

WriteBlockCore:
.IF DEBUG
   lda  #0
   sta  CheckSumLow
   sta  CheckSumHigh
.ENDIF

   lda  #0
   sta  ATADataHigh,x           ;Clear the high byte of the 16 bit interface
                                ; data latch

   jsr  IDEWaitReady
   jsr  Block2LBA               ;program IDE task file

; Write sector from RAM
   lda  #ATACWrite
   sta  ATACommand,x
   jsr  IDEWaitReady

   lda  ATAStatus,x              ;Check for error response from writing command
   and  #$09
   cmp  #$01                     ;if DRQ=0 and ERR=1 an error occured
   bne  wCommandOK

.IF DEBUG
;warning this debug code trashes the Acc register
   jsr DSString
   .byte " Err!:",0
   lda  ATAError,x
   jsr  DSByteCRLF
.ENDIF

; The drive has returned an error code. Just return I/O error code to PRODOS
;
   lda  #PRODOS_IO_ERROR
   sec
   rts
;
; Sector is ready to write
;
wCommandOK:
   ldy  #2
   sty  zpt1
   ldy  #0

wLoop:
   lda  ATAStatus,x             ;Note: not using IDEWaitReady, using inline code
   bmi  wLoop                   ;Wait for BUSY (bit 7) to be zero
   and  #$08                    ;get DRQ status bit
   beq  wShort                  ;if off, didn't get enough data

   lda  (pdIOBuffer),y
   pha

.IF DEBUG
   clc
   adc  CheckSumLow
   sta  CheckSumLow
.ENDIF

   iny
   lda  (pdIOBuffer),y
   sta  ATADataHigh,x

.IF DEBUG
   adc  CheckSumHigh
   sta  CheckSumHigh
.ENDIF

   lda  SetCSMask,x             ;any access sets mask bit to block IDE -CS0 on
                                ; I/O read to drive
   pla
   sta  ATADataLow,x            ;Remember that all write cycles are
                                ; preceded by a read cycle on the 6502
   lda  ClearCSMask,x           ;Set back to normal, allow CS0 assertions on
                                ; read cycles

   iny
   bne  wLoop
   inc  pdIOBufferH
   dec  zpt1
   bne  wLoop

.IF DEBUG
; Display the Checksum
; warning this debug code trashes the Acc register
   jsr  DSString
   .byte " Chk$",0
   lda  CheckSumHigh
   jsr  DSByte
   lda  CheckSumLow
   jsr  DSByteCRLF
.ENDIF

   lda  #0
   clc
   rts
;
; The Block was short, return I/O error code to PRODOS
;
wShort:
.IF DEBUG
; Display "W:Short"
   jsr  DSString
   .byte " W:Shrt:", 0

   lda  zpt1
   jsr  DSByte
   tya
   jsr  DSByteCRLF
.ENDIF

   lda  #PRODOS_IO_ERROR
   sec
   rts

;------------------------------------------------------------------------------
; Block2LBA - Translates ProDOS block# into LBA and programs devices' task file
;             registers.
;
; Input:
;       pd Command Block Data $42 - $47
;       X = requested slot number in form $n0 where n = slot 1 to 7
;       Y = $0n (n = slot#) for accessing scratchpad RAM;
;
; Ouput:
;       None
;
; ZeroPage Usage:
;       None
;
; CPU Registers changed:  A, P
;
; This function translates the block number sent in the PRODOS request
; packet, into an ATA Logical Block Address (LBA).
; The least significant 16 bits becomes the ProDOS block#.
; The most significant 16 becomes the ProDOS Drive #
;
; A ProDOS block and a ATA sector are both 512 bytes.
;
; Logical Block Mode, the Logical Block Address is interpreted as follows:
; LBA07-LBA00: Sector Number Register D7-D0.
; LBA15-LBA08: Cylinder Low Register D7-D0.
; LBA23-LBA16: Cylinder High Register D7-D0.
; LBA27-LBA24: Drive/Head Register bits HS3-HS0.


Block2LBA:

   lda  #$E0                    ;1, (LBA), 1, (Drive), LBA 27-24, where LBA=1,
                                ; Drive=0
   sta  ATAHead,x               ;Talk to the Master device and use LBA mode.
                                ; Remember that this write will seen by both
                                ; the master and slave devices.
;
; Add BLOCKOFFSET to the ProDOS block number to offset the first drive block we
; use. This keeps the device's first BLOCKOFFSET blocks free, which usually
; includes a MBR at block 0.
;
   lda  DrvMiscFlags,y           ; bit 7 = raw block access
   and  #$80
   eor  #$80
   beq  rawBlocks
   lda  #BLOCKOFFSET
rawBlocks:                      ; A = $00 or BLOCKOFFSET
   clc
   adc  pdBlockNumber
   sta  ATASector,x             ;store ProDOS Low block # into LBA 0-7

   lda  pdBlockNumberH
   adc  #0                      ;account for any overflow in LBA 0-7
   sta  ATACylinder,x           ;store ProDOS High block # into LBA 15-8

   lda DriveNumber,y
   adc #0                        ;account for overflow from LBA 8-15
   sta ATACylinderH,x            ;store LBA bits 23-16

   lda #1
   sta ATASectorCnt,x
   rts

;------------------------------------------------------------------------------
; IDEWaitReady - Waits for BUSY flag to clear, and returns DRQ bit status
;
; Input:
;       X = requested slot number in form $n0 where n = slot 1 to 7
; Ouput:
;       Carry flag = DRQ status bit
;
; ZeroPage Usage:
;       None
;
; CPU Registers changed:  A, P
;
IDEWaitReady:
   lda  ATAStatus,x
   bmi  IDEWaitReady            ;Wait for BUSY (bit 7) to be zero
   ror                          ;shift DRQ status bit into the Carry bit
   ror
   ror
   ror
   rts

;------------------------------------------------------------------------------
; CheckDevice - Check to see if a device is attached to the interface.
; Input:
;       X = requested slot number in form $n0 where n = slot 1 to 7
; Output:
;       Carry flag: 0 = Device Present, 1 = Device Missing
;
; CPU Registers changed:  A, P
;
;  Checks to see if the drive status register is readable and equal to $50
;  If so, return with the Carry clear, otherwise return with the carry set.
;  Waits up to 10sec on a standard 1Mhz Apple II for drive to become ready
;
CheckDevice:
   tya
   pha
   lda  ClearCSMask,x           ;reset MASK bit in PLD for normal CS0 signaling
   lda  #$E0                    ;$E0 = [1, LBA, 1, Drive, LBA 27-24]  where
                                ; LBA=1, Drive=0
   sta  ATAHead,x               ;Make sure ATA master drive is accessed

   ldy  #0
chkLoop:
   lda  ATAStatus,x
   and  #%11010000
   cmp  #$50                    ;if BUSY= 0 and RDY=1 and DSC=1
   beq  DeviceFound
   lda  #WAIT_100ms
   jsr  Wait                    ;Wait 100ms for device to be ready
   iny
   cpy  #100                    ;Wait up to 10 seconds for drive to be ready
                                ; This time may turn out to be much shorter on
                                ; accelerated Apple IIs
   bne chkLoop

   sec                          ;set c = 1 if drive is not attached
   bcs  DeviceExit

DeviceFound:
   clc                          ;set c = 0 if drive is attached

DeviceExit:
   pla
   tay
   rts

;------------------------------------------------------------------------------
;  Wait - Copy of Apple's wait routine. Can't use ROM based routine in case
;         ROM is not active when we need it.
;
; Input:
;       A = desired delay time, where Delay(us) = .5(5A^2 + 27A + 26)
;       or more usefully: A = (Delay[in uS]/2.5 + 2.09)^.5 - 2.7
;
; CPU Registers changed:  A, P
;
Wait:
   sec

Wait2:
   pha

Wait3:
   sbc  #1
   bne  Wait3
   pla
   sbc  #1
   bne  Wait2
   rts




.IF DEBUG

;------------------------------------------------------------------------------
; DisplayParms - Display the parameters of the ProDOS request
; Input:
;       None
; Ouput:
;       None
;
; ZeroPage Usage:
;       None
;
; CPU Registers changed:  A, P
;
DisplayParms:
   jsr  DSString
   .byte " B:",0

   lda  pdBlockNumberH
   jsr  DSByte
   lda  pdBlockNumber
   jsr  DSByte

   jsr  DSString
   .byte " U:",0
   lda  pdUnitNumber
   jsr  DSByte

   jsr  DSString
   .byte " A$",0

   lda  pdIOBufferH
   jsr  DSByte

   lda  pdIOBuffer
   jmp  DSByte


;------------------------------------------------------------------------------
; DSString - Sends a String to the Super Serial Card in Slot 2
; Input:
;       string must immediately follow the JSR to this function
;       and be terminated with zero byte.
; Ouput:
;       None
;
; ZeroPage Usage:
;       MsgPointerLow, MsgPointerHi
;
; CPU Registers changed:  A, P
;
DSString:
   pha                          ;save the Acc reg
   txa
   pha                          ;save the X reg
   tya
   pha                          ;save the Y reg
   tsx                          ;put the stack pointer in X
   lda  MsgPointerLow
   pha                          ;push zero page location on stack
   lda  MsgPointerHi
   pha                          ;push zero page location on stack

   lda  StackBase+4,x           ;determine the location of message to display
   clc
   adc  #$01                    ;add 1 because JSR pushes the last byte of its
   sta  MsgPointerLow           ; destination address on the stack

   lda  StackBase+5,x
   adc  #0
   sta  MsgPointerHi

dss1:
   ldy  #0
   lda  (MsgPointerLow),y
   beq  dssend
   jsr  DSChar                  ;display message
   inc  MsgPointerLow
   bne  dss1
   inc  MsgPointerHi
   jmp  dss1

dssend:

   lda  MsgPointerHi
   sta  StackBase+5,x
   lda  MsgPointerLow
   sta  StackBase+4,x           ;fix up the return address on the stack.

   pla
   sta  MsgPointerHi            ;restore zero page location
   pla
   sta  MsgPointerLow           ;restore zero page location
   pla
   tay
   pla
   tax
   pla
   rts                          ;return to location after string's null.

;------------------------------------------------------------------------------
; DSByteCRLF - Sends a Hex byte followed by a CR LF to the Super Serial
; Card in Slot 2
;
; Input:
;       A = Hex number to display
; Ouput:
;       None
;
; CPU Registers changed:  A, P
;
DSByteCRLF:
   jsr DSByte
DSCRLF:
   lda  #$0D
   jsr  DSChar
   lda  #$0A
   jmp  DSChar

;------------------------------------------------------------------------------
; DSByte - Sends a Hex byte to the Super Serial Card in Slot 2
; Input:
;       A = Hex number to display
; Ouput:
;       None
;
; CPU Registers changed:  A, P
;
DSByte:
   pha
   lsr a
   lsr a
   lsr a
   lsr a
   jsr DSNibble
   pla
DSNibble:
   and #$0F
   ora #$30
   cmp #$30+10
   bcc digit
   adc #6
digit:
   jmp DSChar

;------------------------------------------------------------------------------
; DSChar - Sends a char to the Super Serial Card in Slot 2
; Input:
;       A = Character to Send
;       mslot = should contain current slot number of CFFA
; Ouput:
;       (data out serial port)
;
; ZeroPage Usage:
;       None
;
; CPU Registers changed:  P
;
DSBlank:
   lda #$20
DSChar:
   pha
   tya
   pha
   lda  mslot
   and  #$0f
   tay                          ;Y reg now has $0n for accessing scratchpad RAM
   lda  SerialInitDone,y
   cmp  #$A5
   beq  dsc0

; Init the serial port if sig byte is not $A5.
; Set up serial port on the Apple Super Serial card. Always assume slot 2.
   lda  #$1f
   sta  $c0ab                   ;control register
   lda  #$0b
   sta  $c0aa                   ;format
   lda  $c0a9                   ;clear status
   lda  #$A5
   sta  SerialInitDone,y

dsc0:
   lda  $c0a9
   and  #%00010000              ;Transmit register empty?
   beq  dsc0                    ;If not, wait

   pla
   tay
   pla                          ;get byte back
   sta  $c0a8                   ;send it
   rts

.ENDIF
