CFFA - CompactFlash (CF) Interface for Apple II's Firmware - EPROM Version 1.3    June 5, 2004

This version of the CFFA EPROM now includes new firmware to support the 6502.
This EPROM includes all of the orignal version 1.2 code in the same location on the EPROM
and also new 6502 specific code located at EPROM offset: $4000 and can be accessed by
jumpering J6 as follows: A12 & A13 jumpers IN, A14 jumper OUT.

spdrv6502.bin v1.0 may be used in any apple ][ that will run ProDOS.

Project Home: http://dreher.net/CFforAppleII/

This is an open source project to put a CompactFlash memory card into any Apple II.

The firmware in this project is for your reference and education only.
I make no guarantees or warranties for this software and I can't be held
responsible any damagages resulting from this software's use.

This software is free to use, modify or redistribute as you see fit.
If you find this code useful or interesting please send me an Email
and let me know. Email: rich@dreher.net


Files in this distribution:

(1) spdrv6502.s        	SmartPort compatiable CompactFlash/IDE firmware source file
			This file has to be assembled several times with different options
			selected to generate the EPROM ready file. The pieces are then
			combined together using the EPROM programmer software.

(2) spdrv6502.lst	Assembler listing file for the default selected firmware.

(3) CFFAv1.30.bin	EPROM ready binary of EPROM firmware

(4) go.bat              Simple DOS batch file to compile driver. Assumes
                        CA65 Cross assembler is installed properly.
                        Go to: http://www.cc65.org/  to find assembler


Special thanks to contributors:
Chris Schumann
Dave Lyons









