# WD1797Imager
Disk imaging program for Heathkit Soft-Sector disks based on WD1797 disk controller.

Assemble this program on a Heathkit computer (H8 with H37 or H89 with H89-37) using HDOS ASM then run the program on the Heathkit computer under the HDOS operating system.

Connect a host PC to the Heathkit computer on port 340Q and launch H8DUtility3 (see link below).

Works together with the host software [H8DUtility3](https://github.com/lesbird/H8DUtility3) - these 2 projects will mostly stay in sync. Features added to WD1797Imager will be supported by H8DUtility3 on the host PC.

Switch to the DISK IMAGER in H8DUtility3 and click the "CLIENT STATUS" button.

Supported formats
* 5 sector 1024 bytes CP/M
* 8 sector 512 bytes ZDOS/MSDOS
* 9 sector 512 bytes ZDOS/MSDOS
* 10 sector 256 bytes single density
* 16 sector 256 bytes CP/M and HDOS

