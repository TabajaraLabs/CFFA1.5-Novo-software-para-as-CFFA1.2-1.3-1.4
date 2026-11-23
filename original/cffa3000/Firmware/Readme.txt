CFFA3000 Firmware Release v3.1    1/26/2013

This release contains a v3.1 firmware with folder (directory) support. Also included with this release is a fall-back version of firmware: v3.0.3.
At any point after updating to v3.1 beta 1, if you want to go back to an older firmware, we recommend you install v3.0.3 instead of the v3.0.2 that you 
most likely had installed on your card when you upgraded firmware.

If you have questions, please feel free to email me at rich@dreher.net for support.

-Rich


----------- CFFA3000 v3.0.3 Notes ----------

* Fixes a problem in 3.0.2 and earlier which prevented a menu-driven firmware upgrade, if the CFFA3000's microcontroller has ever contained firmware larger than 112K.
  If you install 3.1 and then need to install an older version, use 3.0.3.  If you go back to 3.0.2 or earlier you can still upgrade the firmware, but you must use
    the "DIP Switch 7 + power on" method.


-------- CFFA3000 v3.1 Notes ---------

== How to Upgrade ==

Put both CFFA.BIN and CFFA.XSV onto a Compact Flash card (NOTE: You cannot use a USB flash drive for this).
Insert the CF card into the CFFA3000 and enter the CFFA3000 menus.
The CFFA3000 will offer to upgrade to v3.1, and after that it will offer to update the CPLD to version 6.

== Folders ==

Now allows folders on FAT volumes, making it easier to organize a large number of disk image files. Folder names will appear with a trailing '/'.
Press <Return> on a folder to navigate into the folder. Press '-' (or use <Ctrl>X, or <Apple>UpArrow) to move back up to a parent folder.

The firmware will remember the current folder for both the CF and USB media. The path shows up at the top left, above "Items:" to separate the current-folder lines from
the contents below. The current folder always resets to the top level when you insert the USB drive or CF card.

You can use folders inside folders, up to 8 levels deep.  The item list can only show up to 255 items in a particular folder; if you have more files than that, please break
them up into sub-folders.

== Assignments Screens ==

<Crtl>B: Now reboots the slot for which you're making assignments.
Disk II assignments: Comma and Period rotate among the panes.
SmartPort Assignments: When there are more configured images than the "SmartPort Devices" setting, the extra ones appear at the bottom of the right-hand column,
marked with '*', and if you highlight one you'll see "(Unavailable - SmartPort full)".

Pressing '-' in a right-side pane deletes an assignment (like Delete / Control-D).

<Apple>Space in the right-hand column toggles between SmartPort and Disk II assignments.
Apple IIgs only: <Shift>Tab cycles backwards through the panes (like Comma does).

== Menus ==

When a menu item for an adjustable setting it highlighted, '<' and '>' indicators now show which ways the menu item can be adjusted.

The "Quit" or "Boot" menu item now lets you choose which slot to boot from, using the Left and Right arrows.
    Quit: Without Booting
    Boot: Slot N
    Boot: Slot N (Continue)
    Boot: Reboot

In the "Other Settings" menu, replaced "Delay for Menu Key" setting with "Menu at Boot" which may select from "Always", 0.1s..0.2s....up to 25 seconds.
If you choose "Menu at Boot: Always" and your Apple II finds the CFFA3000 at startup, you'll be able to press Return to continue booting the CFFA3000,
or use the arrow keys to choose another slot.

The menus use some MouseText characters (when running on an Apple IIgs or an Apple //e enhanced).
If you don't want to use MouseText, you can turn on DIP Switch 2.

== Performance ==

The CFFA3000 does read-ahead caching from USB or CF, while the Apple II is busy copying the previous block. This requires CPLD v6. Which version you have
may be checked any time by going into the menu and selecting the "About" menu. The CPLD version is displayed near the top of the screen.

Various speed improvements in the 6502 and 65816 firmware including faster coordination with the CFFA3000's microcontroller, and faster entry for ProDOS
and SmartPort calls to the card.

== New DIP Switches ==

DIP Switch 1: Flip on if your Apple II or Apple II+ has a "lowercase chip" to allow the CFFA3000 to display lowercase letters.
DIP Switch 2: Flip on if you don't want to use MouseText.
DIP Switch 4: Flip on if you are using an Apple III. Since Apple III requires the GS DIP Switch to be on, this lets the CFFA3000 know whether it must use the 6502 firmware or the 65816 firmware.

Note 1: To use the CFFA3000 on an Apple III, you must turn on both the GS DIP Switch 7 and DIP Switch 4.
Note 2: The firmware will optimize for the GS's 65816 when the GS DIP Switch 7 is on and Switch 4 is off.

== Compatibility ==

The end of the Disk II slot ROM now more closely resembles a real Disk II.  This makes at least one version of Karateka work.
