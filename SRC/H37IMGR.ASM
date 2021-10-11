*
* H37IMGR
*
* 2021.09.30 LES BIRD
* ALSO WORKS FOR PC/Z100 5.25 DISKS (WD179X)
*
        XTEXT   HOSEQU
        XTEXT   HOSDEF
        XTEXT   H37DEF
        XTEXT   HROM
*
BUFSIZ  EQU     8192            DISK TRACK BUFFER SIZE
BAUD96  EQU     0CH             9,600 BAUD
BAUD19  EQU     06H             19,200 BAUD
BAUD38  EQU     03H             38,400 BAUD
BAUD56  EQU     02H             56,000 BAUD
*
BAUDIV  EQU     03H             19200 BAUD IS DEFAULT
*
DLY     EQU     53A
UIVEC   EQU     40037A          USER INTERRUPT VECTOR
BLKICW  EQU     40067A          INTERRUPT RETURN ADDRESS
AIO.UNI EQU     41061A          CURRENT DEVICE
*
MI.JMP  EQU     303Q
* Ports for H8-4
LP4     EQU     0E0H
TX4     EQU     LP4
RX4     EQU     LP4
DVL4    EQU     LP4
DVH4    EQU     LP4+1
IER4    EQU     LP4+1
LCNTL4  EQU     LP4+3
MCNTL4  EQU     LP4+4
LSTAT4  EQU     LP4+5
*
TX5     EQU     350Q
RX5     EQU     350Q
LSTAT5  EQU     TX5+5
*
        ORG     USERFWA
*
START   EQU     *
        LXI     D,BUFSIZ
        LXI     H,SECBUF
        CALL    ZEROMEM
* DISMOUNT ALL DRIVES
        LXI     H,DEV1
        SCALL   .DMNMS
        LXI     H,DEV2
        SCALL   .DMNMS
        LXI     H,DEV3
        SCALL   .DMNMS
*
        CALL    SINT
*
        JMP     BEGIN
*
* SETUP LPT PORT FOR XXXX,8N2
*
SINT    EQU     *
        XRA     A
        OUT     LCNTL4
        OUT     IER4
        OUT     MCNTL4
        DCR     A
        OUT     LCNTL4
        MVI     A,BAUDIV
        OUT     DVL4
        XRA     A
        OUT     DVH4
        MVI     A,07H
        OUT     LCNTL4
        IN      LSTAT4
        IN      RX4
        RET
*
* SEND A CHAR IN (A) TO THE LP PORT (340Q)
*
CHROUT  PUSH    PSW
CHRO4   IN      LSTAT4
        ANI     60H
        CPI     60H
        JNZ     CHRO4
        POP     PSW
        OUT     TX4
        RET
*
* READ A CHAR FROM THE LP PORT (340Q)
*
CHRIN   IN      LSTAT4
        RAR
        JNC     CHRIN
        IN      RX4
        RET
*
CHRRDY  IN      LSTAT4
        RAR
        RET                     Returns NC = no char, C = char ready
* DIRECT OUT TO CONSOLE PORT
OUT350  PUSH    PSW
OUT35A  IN      LSTAT5
        ANI     60H
        CPI     60H
        JNZ     OUT35A
        POP     PSW
        OUT     TX5
        RET
*
ZEROMEM EQU     *
        XRA     A
        MOV     M,A
        INX     H
        DCX     D
        MOV     A,E
        ORA     D
        JNZ     ZEROMEM
        RET
* FLIP LATCH TO COMMAND MODE
H37CMD  EQU     *
        MVI     A,CON.CD
        OUT     DK.INT
        RET
* FLIP LATCH TO SECTOR/TRACK MODE
H37TRK  EQU     *
        MVI     A,CON.ST
        OUT     DK.INT
        RET
*
BITS    EQU     *
        PUSH    B
        PUSH    PSW
        MVI     A,10000000B
        INR     B
BITS1   RLC
        DCR     B
        JNZ     BITS1
        MOV     C,A
        POP     PSW
        ORA     C
        POP     B
        RET
* INT4 ROUTINE
MYINT   EQU     *
        IN      FD.STAT
        POP     H
        LHLD    BLKICW
        EI
        PCHL
*
RSTBSY  EQU     *
        MVI     A,FDC.FI
        OUT     FD.CMD
        MVI     A,1
        CALL    DLY
        IN      FD.STAT
        RET
* DISK DRIVE UNIT TO WD1797 BITS
UNIBITS EQU     *
        LDA     AIO.UNI
        ADI     4
        MOV     B,A
        XRA     A
        CALL    BITS
        RET
* SELECT AIO.UNI
SELDRV  EQU     *
        PUSH    B
        CALL    H37CMD
        CALL    SETDENS
        EI
        MVI     A,300/2
        CALL    DLY
        POP     B
        RET
* SET DENSITY FROM (DENS)
SETDENS EQU     *
        CALL    UNIBITS         A=DRIVE BIT
        ORI     CON.MO+CON.EI
        MOV     C,A
        LDA     DENS            CON.MFM OR 0
        ORA     C
        STA     CONCMD          DS0+CON.MO+CON.EI+CON.MFM
        OUT     DK.CON
        RET
*
SETMFM  EQU     *
        MVI     A,CON.MFM
        STA     DENS
        JMP     SETDENS
*
SETFM   EQU     *
        MVI     A,0
        STA     DENS
        JMP     SETDENS
* SWITCH DENSITY FM<->MFM
CHGDENS EQU     *
        LDA     DENS
        CPI     CON.MFM
        JZ      SETFM
        JMP     SETMFM
* DESELECT ALL DRIVES
DSLDRV  EQU     *
        PUSH    PSW
        MVI     A,FDC.FI
        OUT     FD.CMD
        XRA     A
        OUT     DK.CON
        POP     PSW
        RET
* 40MS DELAY
DLY40   EQU     *
        PUSH    PSW
        PUSH    B
        LXI     B,3200
DLY40A  DCX     B
        MOV     A,B
        ORA     C
        JNZ     DLY40A
        POP     B
        POP     PSW
        RET
* SET UP INTERRUPT 4 VECTOR
SUPINT  EQU     *
        LXI     H,MYINT
        SHLD    UIVEC+9+1
        MVI     A,MI.JMP
        STA     UIVEC+9
        RET
* WAIT HERE UNTIL INTERRUPT JUMPS TO BLKICW
WAITINT EQU     *
        JMP     WAITINT
* C=TRACK
STPIN   EQU     *
        CALL    SELDRV
        LXI     H,STPI2
        SHLD    BLKICW
STPI1   EQU     *
        MVI     A,FDC.STI+FDF.S20
        OUT     FD.CMD
        JMP     WAITINT
STPI2   EQU     *
        LDA     CURTRK
        INR     A
        STA     CURTRK
        CMP     C
        JNZ     STPI1
        CALL    DLY40
        RET
* C=TRACK
STPOUT  EQU     *
        CALL    SELDRV
        LDA     CURTRK
        ORA     A
        JZ      SEEK0
        LXI     H,STPO2
        SHLD    BLKICW
STPO1   EQU     *
        MVI     A,FDC.STO+FDF.S20
        OUT     FD.CMD
        JMP     WAITINT
STPO2   EQU     *
        LDA     CURTRK
        DCR     A
        STA     CURTRK
        CMP     C
        JNZ     STPO1
        CALL    DLY40
        RET
* SEEK TO TRACK 0
SEEK0   EQU     *
        CALL    SELDRV
        XRA     A
        STA     CURTRK
        LXI     H,SEEKD
        SHLD    BLKICW
        MVI     A,FDC.RST+FDF.S20
        OUT     FD.CMD
        JMP     WAITINT
SEEKD   EQU     *
        MVI     E,10            STEP IN 10 TIMES
        LXI     H,SEEKD2
        SHLD    BLKICW
SEEKD1  EQU     *
        MVI     A,FDC.STI+FDF.S20
        OUT     FD.CMD
        JMP     WAITINT
SEEKD2  EQU     *
        DCR     E
        JNZ     SEEKD1
* DOUBLE RESTORE
        LXI     H,SEEKD3
        SHLD    BLKICW
        MVI     A,FDC.RST+FDF.S20
        OUT     FD.CMD
        JMP     WAITINT
SEEKD3  EQU     *
        CALL    DLY40           HEAD SETTLE TIME
        ANI     FDS.TK0
        RNZ
        STC
        RET
* C=TRK (STEP IN OR OUT TO REACH TARGET)
SEEKTO  EQU     *
        CALL    H37TRK
        MOV     A,C
        OUT     FD.TRK          SET TRACK REGISTER
        LDA     CURTRK
        SUB     C
        RZ                      ALREADY AT TRK C
        JC      STPIN
        JMP     STPOUT
* DE=BUFFER - READ TRACK INTO BUFFER
READLP  EQU     *
        LXI     B,0             TOTAL BYTES READ
        LXI     H,READL2        RETURN ADDRESS
        SHLD    BLKICW
        CALL    H37CMD
        LDA     CONCMD
        ORI     CON.DRQ
        OUT     DK.CON
* RDS=READ SECTOR
* DLF=15MS DELAY
* MRF=READ TO END OF TRACK
* SLF=SECTOR LEN SHIFT (128,256,512,1024)
* SS1=SIDE 1 FLAG
        XRA     A
        LDA     SIDE            0=SIDE 1,1=SIDE 2
        RAL                     IF A=1 THEN RAL=FDF.SS1
        ORI     FDC.RDS+FDF.DLF+FDF.MRF+FDF.SLF
        OUT     FD.CMD
        LXI     H,READL1
READL1  EQU     *               LOOP UNTIL IRQ4
        HLT                     WAIT FOR DRQ
        IN      FD.DAT
        STAX    D
        INX     D
        INX     B
        PCHL                    LOOP BACK TO READL1
READL2  EQU     *
        MVI     A,CON.MO
        OUT     DK.CON
        MOV     L,C
        MOV     H,B
        SHLD    RDCNT
        CALL    H37TRK
        IN      FD.SEC
        DCR     A
        STA     SPERT
        ORA     A               SECTORS PER TRACK == 0?
        RNZ                     NO ERRORS
        STC                     ERROR, SET CARRY FLAG
        RET
* B=SEC (1-255),C=TRK (0-255)
READS   EQU     *
        CALL    H37TRK
        MOV     A,B
        OUT     FD.SEC          SET SECTOR REGISTER
        CALL    SEEKTO
        LXI     D,SECBUF
        JMP     READLP
*
* IMAGER COMMANDS
* R = READ IMAGE SEND TO HOST
* W = WRITE IMAGE FROM HOST
* 0 = DK0
* 1 = DK1
* 4 = 1S40T
* 5 = 2S40T
* 6 = 1S80T
* 7 = 2S80T
* A = SIDE 1
* B = SIDE 2
* E = EXAMINE TRACK
* Q = QUERY DISK TYPE
* T = QUERY TRACK HEADER
*
BEGIN   EQU     *
        CALL    $TYPTX
        DB      0AH,'H37IMGR 2021.09.30 BY LES BIRD',0AH
        DB      'SOFT SECTOR DISK IMAGING PROGRAM',0AH
        DB      'DRIVE CONFIGURATION SHOULD BE AS FOLLOWS:',0AH
        DB      'DK0: DS 40 TRACK',0AH
        DB      'DK1: DS 80 TRACK',8AH
        CALL    H37CMD
        CALL    RSTBSY
        CALL    SUPINT
        XRA     A               SET DRIVE UNIT TO 0
        STA     AIO.UNI
        INR     A
        STA     NUMSID          SINGLE SIDE IS DEFAULT
        MVI     A,40
        STA     NUMTRK          40 TRACK IS DEFAULT
        CALL    SELDRV
        CALL    SEEK0           SEEK TRACK 0
BEGLP   EQU     *
        CALL    $TYPTX
        DB      'WAITING FOR COMMAND:',80H
        CALL    DSLDRV
BEGLP1  EQU     *
        CALL    CHRIN           WAIT FOR COMMAND FROM LP PORT
        CPI     'R'             READ DISK IMAGE
        JZ      CMDRDI
        CPI     'W'
        JZ      CMDWDI
        CPI     '0'
        JZ      SETDK0
        CPI     '1'
        JZ      SETDK1
        CPI     '3'             IDENTIFY AS H37IMGR
        JZ      ISH37
        CPI     '4'
        JZ      SET1S4
        CPI     '5'
        JZ      SET2S4
        CPI     '6'
        JZ      SET1S8
        CPI     '7'
        JZ      SET2S8
        CPI     'Q'
        JZ      QUERY
        CPI     'T'
        JZ      GETTRK
        CPI     'E'
        JZ      EXMTRK
        CPI     'A'
        JZ      SETSID1
        CPI     'B'
        JZ      SETSID2
        MVI     A,'?'
        CALL    CHROUT
        JMP     BEGLP1
* CMD READ DISK IMAGE
CMDRDI  EQU     *
        CALL    $TYPTX
        DB      'READ DISK IMAGE',8AH
        CALL    SELDRV
        XRA     A
        STA     SIDE            INITIALIZE SIDE
        LXI     B,0100H         START SECTOR 1, TRACK 0
CMDRD1  EQU     *
        CALL    CHRIN           WAIT FOR REQUEST
        CPI     'R'
        JNZ     BEGLP           NOT 'R' SO PROBABLY ABORT
        PUSH    B
        MVI     A,'R'
        CALL    OUT350
*
        CALL    READS           READ TRACK
*
        MVI     A,08H
        CALL    OUT350
        MVI     A,'S'
        CALL    OUT350          SHOW SENDING BUFFER
*
        CALL    SENDT           SEND TRACK BUFFER
*
        MVI     A,08H
        CALL    OUT350
        MVI     A,'*'
        CALL    OUT350          SHOW TRACK SENT
        POP     B               GET SEC,TRK
        LDA     NUMSID          1 OR 2
        DCR     A
        JZ      CMDRD2          SINGLE SIDED
        LDA     SIDE            0 OR 1
        ORA     A
        JNZ     CMDRD2          FINISHED SIDE 2
        INR     A
        STA     SIDE
        JMP     CMDRD1          READ SIDE 2
CMDRD2  EQU     *
        XRA     A
        STA     SIDE            SET SIDE 1
        INR     C
        LDA     NUMTRK
        CMP     C
        JNZ     CMDRD1
        MVI     A,0DH
        CALL    OUT350
        MVI     A,0AH
        CALL    OUT350
        JMP     BEGLP
* SEND TRACK DATA TO 340Q
SENDT   EQU     *
        LHLD    RDCNT
        MOV     A,L
        CALL    CHROUT
        MOV     A,H
        CALL    CHROUT
        LDA     SPERT
        CALL    CHROUT
        MOV     A,L
        ORA     H
        JZ      SENDT2
        LXI     D,SECBUF
SENDT1  EQU     *
        LDAX    D
        CALL    CHROUT
        INX     D
        DCX     H
        MOV     A,L
        ORA     H
        JNZ     SENDT1
SENDT2  EQU     *
        MVI     A,'R'
        CALL    CHROUT          HANDSHAKE
        RET
* COMMAND WRITE DISK IMAGE
CMDWDI  EQU     *
        RET
* COMMAND SET DRIVE 0
SETDK0  EQU     *
        PUSH    PSW
        CALL    $TYPTX
        DB      'SET DK0',8AH
        XRA     A
        STA     AIO.UNI
        CALL    SEEK0
        POP     PSW
        CALL    CHROUT          HANDSHAKE
        JMP     BEGLP
* COMMAND SET DRIVE 1
SETDK1  EQU     *
        PUSH    PSW
        CALL    $TYPTX
        DB      'SET DK1',8AH
        MVI     A,1
        STA     AIO.UNI
        CALL    SEEK0
        POP     PSW
        CALL    CHROUT
        JMP     BEGLP
* H37 IMAGER IDENTIFIER
ISH37   EQU     *
        CALL    CHROUT
        CALL    $TYPTX
        DB      'IDENTIFY AS H37IMGR',8AH
        JMP     BEGLP
* SET DRIVE PARAMETERS (SIDES,TRACKS)
SETPAR  EQU     *
        MOV     A,B
        STA     NUMSID
        MOV     A,C
        STA     NUMTRK
        RET
* COMMAND SET SS 40 TRACK
SET1S4  EQU     *
        PUSH    PSW
        CALL    $TYPTX
        DB      'SET SS 40 TRACK',8AH
        LXI     B,0128H
        CALL    SETPAR
        XRA     A
        STA     AIO.UNI
        POP     PSW
        CALL    CHROUT
        JMP     BEGLP
* COMMAND SET DS 40 TRACK
SET2S4  EQU     *
        PUSH    PSW
        CALL    $TYPTX
        DB      'SET DS 40 TRACK',8AH
        LXI     B,0228H
        CALL    SETPAR
        XRA     A
        STA     AIO.UNI
        POP     PSW
        CALL    CHROUT
        JMP     BEGLP
* COMMAND SET SS 80 TRACK
SET1S8  EQU     *
        PUSH    PSW
        CALL    $TYPTX
        DB      'SET SS 80 TRACK',8AH
        LXI     B,0150H
        CALL    SETPAR
        MVI     A,1
        STA     AIO.UNI
        POP     PSW
        CALL    CHROUT
        JMP     BEGLP
* COMMAND SET DS 80 TRACK
SET2S8  EQU     *
        PUSH    PSW
        CALL    $TYPTX
        DB      'SET DS 80 TRACK',8AH
        LXI     B,0250H
        CALL    SETPAR
        MVI     A,1
        STA     AIO.UNI
        POP     PSW
        CALL    CHROUT
        JMP     BEGLP
* COMMAND QUERY DISK TYPE
QUERY   EQU     *
        CALL    CHROUT
        CALL    $TYPTX
        DB      'QUERY DISK TYPE',8AH
        LXI     B,0             SEC,TRK=0
        CALL    QUERY1
        CALL    QUERYR
        JMP     BEGLP
QUERYR  EQU     *
        LDA     SPERT           SECTORS PER TRACK
        CALL    CHROUT
* READ ADDRESS RESULTS
        LDA     QTRK            TRACK
        CALL    CHROUT
        LDA     QSID            SIDE
        CALL    CHROUT
        LDA     QSEC            SECTOR
        CALL    CHROUT
        LDA     QSECL           SECTOR LENGTH
        CALL    CHROUT
        LDA     QCRC1           CRC 1
        CALL    CHROUT
        LDA     QCRC2           CRC 2
        CALL    CHROUT
* DISK PARAMETERS
        LDA     NUMSID          NUM SIDES
        CALL    CHROUT
        LHLD    RDCNT
        MOV     A,L             RDCNT LOW BYTE
        CALL    CHROUT
        MOV     A,H             RDCNT HIGH BYTE
        CALL    CHROUT
        LDA     DENS            DENSITY CON.MFM OR 0
        CALL    CHROUT
        RET
* READ/DETERMINE DISK TYPE
QUERY1  EQU     *
        XRA     A
        STA     SPERT
        MVI     A,CON.MFM       TEST MFM FIRST
        STA     DENS
        CALL    SELDRV
        LXI     D,BUFSIZ
        LXI     H,SECBUF
        CALL    ZEROMEM
QUERYL  EQU     *
        MVI     A,2
        STA     NUMSID          DOUBLE SIDED DEFAULT
        DCR     A
        STA     SIDE
        MOV     B,A             SECTOR 1, C=TRK
        CALL    READS           TEST READ SIDE 2
        PUSH    PSW
        XRA     A
        STA     SIDE
        POP     PSW
        JNC     QUERYS          GOOD DOUBLE SIDE READ
        MVI     A,1
        STA     NUMSID          SINGLE SIDED DISK
        MOV     B,A
        LDA     CURTRK
        MOV     C,A
        CALL    READS           READ A TRACK FILL SPERT+RDCNT
        JNC     QUERYS          GOOD SINGLE SIDE READ
        LDA     DENS
        CPI     CON.MFM
        JNZ     QUERY3          FAILED MFM AND FM
        CALL    $TYPTX
        DB      'CHECKING SINGLE DENSITY',8AH
        CALL    CHGDENS         MIGHT BE FM
        LDA     CURTRK
        MOV     C,A
        JMP     QUERYL
* JUST READ THE HEADER
QUERYS  EQU     *
        CALL    H37CMD
        LXI     H,QUERY3
        SHLD    BLKICW
        LDA     CONCMD
        ORI     CON.DRQ
        OUT     DK.CON
        LXI     B,0
        LXI     D,QBUF
        LXI     H,QUERY2
        XRA     A
        ORI     FDC.RDA+FDF.DLF
        OUT     FD.CMD
QUERY2  EQU     *               LOOP UNTIL IRQ4
        HLT                     WAIT FOR DRQ
        IN      FD.DAT
        STAX    D
        INX     D
        INX     B
        PCHL
QUERY3  EQU     *
        MVI     A,FDC.FI
        OUT     FD.CMD
        IN      FD.DAT
        MVI     A,CON.MO
        OUT     DK.CON
        MOV     A,C
        ORA     B
        RNZ
        STC
        RET
* GET TRACK HEADER
GETTRK  EQU     *
        CALL    CHROUT          HANDSHAKE
        CALL    CHRIN           GET TRACK TO CHECK
        MOV     C,A             STORE TRACK
        PUSH    B
        CALL    $TYPTX
        DB      'QUERY TRACK',8AH
        POP     B
        CALL    GETTR0
        CALL    QUERYR
        JMP     BEGLP
GETTR0  EQU     *
        CALL    SETMFM
GETTR1  EQU     *
        CALL    QUERYS
        JNC     GETTR3
        LDA     DENS
        ORA     A
        JZ      GETTR2
        CALL    $TYPTX
        DB      'TRY SINGLE DENSITY',8AH
        CALL    SETFM
        LDA     CURTRK
        MOV     C,A
        JMP     GETTR1
GETTR2  EQU     *
        CALL    $TYPTX
        DB      'DISK NOT RECOGNIZED',8AH
        STC
GETTR3  EQU     *
        RET
*
EXMTRK  EQU     *
        CALL    CHROUT          HANDSHAKE
        CALL    CHRIN
        MOV     C,A             TRACK TO READ
        CALL    QUERY1
        CALL    SENDT
        CALL    QUERYR
        JMP     BEGLP
*
SETSID1 EQU     *
        CALL    CHROUT
        CALL    $TYPTX
        DB      'SET SIDE 1',8AH
        XRA     A
        STA     SIDE
        JMP     BEGLP
*
SETSID2 EQU     *
        CALL    CHROUT
        CALL    $TYPTX
        DB      'SET SIDE 2',8AH
        MVI     A,1
        STA     SIDE
        JMP     BEGLP
*
FMTTRK  EQU     *
        LDA     DENS
        ORA     A
        JNZ     FMTDD
* SINGLE DENSITY FORMAT
FMTSD   EQU     *
        LXI     D,SDTT
        RET
* DOUBLE DENSITY FORMAT
FMTDD   EQU     *
        MVI     A,16
        STA     SPERT
        MVI     A,1
        STA     DDSEC           START SECTOR 1
        LDA     CURTRK
        STA     DDTRK
        LDA     SIDE
        STA     DDSID
        LXI     D,SECBUF
        LXI     H,DDTT
FMTDD1  EQU     *
        MOV     A,M
        INX     H
        MOV     C,M
        INX     H
        ORA     C
        JZ      FMTDD2          END OF SECTOR DATA
        CALL    WDAT
        JMP     FMTDD1
FMTDD2  EQU     *
        LDA     SPERT
        INR     A
        MOV     C,A
        LDA     DDSEC
        INR     A
        STA     DDSEC
        CMP     C
        JNZ     FMTDD1
* WRITE THE TRACK
WRTTRK  EQU     *
        LDA     CONCMD
        ORI     CON.DRQ
        OUT     DK.CON
        MVI     A,FDC.WTT+FDF.DLF
        MOV     L,A
        LDA     SIDE
        ORA     A
        JZ      WRTTR1
        MVI     A,FDF.SS1
        ORA     L
WRTTR1  EQU     *
        LXI     H,WRTTR3
        SHLD    BLKICW
        LXI     H,WRTTR2
        LXI     D,SECBUF
        OUT     FD.CMD
WRTTR2  EQU     *
        HLT
        LDAX    D
        OUT     FD.DAT
        INX     D
        PCHL
WRTTR3  EQU     *
        MVI     A,150           WRITE GATE DELAY
WRTTR4  DCR     A
        JNZ     WRTTR4
        LDA     CONCMD
        OUT     DK.CON
        RET
*
WDAT    STAX    D
        INX     D
        DCR     C
        JNZ     WDAT
        RET
*
DEV1    DB      'SY0:',0
DEV2    DB      'SY1:',0
DEV3    DB      'SY2:',0
*
CURTRK  DB      0               0-79
CURSEC  DB      0               1-16
SIDE    DB      0               0 OR 1
CONCMD  DB      0               LAST COMMAND SENT TO DK.CON
DENS    DB      CON.MFM
*
SPERT   DB      0               SECTORS PER TRACK
RDCNT   DW      0               BYTES READ
NUMTRK  DB      0               NUM TRACKS (40 OR 80)
NUMSID  DB      0               NUM SIDES (1 OR 2)
*
QBUF    EQU     *
QTRK    DB      0
QSID    DB      0
QSEC    DB      0
QSECL   DB      0
QCRC1   DB      0
QCRC2   DB      0
*
DDTT    DB      04EH,40
DDTTA   DB      0,12
        DB      0F5H,3
        DB      0FEH,1
DDTRK   DB      0,1
DDSID   DB      0,1
DDSEC   DB      0,1
        DB      1,1
        DB      0F7H,1
        DB      04EH,22
        DB      0,12
        DB      0F5H,3
        DB      0FBH,1
DDDP1   DB      0E5H,128
DDDP2   DB      0E5H,128
        DB      0F7H,1
        DB      04EH,43
        DB      0,0

SDTT    DB      0FFH,32
SDTTA   DB      0,6
        DB      0FEH,1
SDTRK   DB      0,1
SDSID   DB      0,1
SDSEC   DB      0,1
        DB      1,1
        DB      0F7H,1
        DB      0FFH,11
        DB      0,6
        DB      0FBH,1
SDDP1   DB      0E5H,128
SDDP2   DB      0E5H,128
        DB      0F7H,1
        DB      0FFH,16
        DB      0,0
*
* HEATH 5.25
* FM =10 SECTORS, 256 BYTES (2560 BYTES PER TRACK)
* MFM=16 SECTORS, 256 BYTES (4096 BYTES PER TRACK)
* PC 5.25
* MFM= 9 SECTORS, 512 BYTES (4608 BYTES PER TRACK)
*
SECBUF  DS      BUFSIZ          MAX FULL TRACK
*
        END     START
                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page    1

                        00001   *
                        00002   * H37IMGR
                        00003   *
                        00004   * 2021.09.30 LES BIRD
                        00005   * ALSO WORKS FOR PC/Z100 5.25 DISKS (WD179X)
                        00006   *
   042.200              00007           XTEXT   HOSEQU
   042.200              00035           XTEXT   HOSDEF
   000.207              00101           XTEXT   H37DEF
   000.207              00189           XTEXT   HROM
                        00216   *
   040.000              00217   BUFSIZ  EQU     8192            DISK TRACK BUFFER SIZE
   000.014              00218   BAUD96  EQU     0CH             9,600 BAUD
   000.006              00219   BAUD19  EQU     06H             19,200 BAUD
   000.003              00220   BAUD38  EQU     03H             38,400 BAUD
   000.002              00221   BAUD56  EQU     02H             56,000 BAUD
                        00222   *
   000.003              00223   BAUDIV  EQU     03H             19200 BAUD IS DEFAULT
                        00224   *
   000.053              00225   DLY     EQU     53A
   040.037              00226   UIVEC   EQU     40037A          USER INTERRUPT VECTOR
   040.067              00227   BLKICW  EQU     40067A          INTERRUPT RETURN ADDRESS
   041.061              00228   AIO.UNI EQU     41061A          CURRENT DEVICE
                        00229   *
   000.303              00230   MI.JMP  EQU     303Q
                        00231   * Ports for H8-4
   000.340              00232   LP4     EQU     0E0H
   000.340              00233   TX4     EQU     LP4
   000.340              00234   RX4     EQU     LP4
   000.340              00235   DVL4    EQU     LP4
   000.341              00236   DVH4    EQU     LP4+1
   000.341              00237   IER4    EQU     LP4+1
   000.343              00238   LCNTL4  EQU     LP4+3
   000.344              00239   MCNTL4  EQU     LP4+4
   000.345              00240   LSTAT4  EQU     LP4+5
                        00241   *
   000.350              00242   TX5     EQU     350Q
   000.350              00243   RX5     EQU     350Q
   000.355              00244   LSTAT5  EQU     TX5+5
                        00245   *
   042.200              00246           ORG     USERFWA
                        00247   *
   042.200              00248   START   EQU     *
   042.200  021 000 040 00249           LXI     D,BUFSIZ
   042.203  041 232 051 00250           LXI     H,SECBUF
   042.206  315 341 042 00251           CALL    ZEROMEM
                        00252   * DISMOUNT ALL DRIVES
   042.211  041 067 051 00253           LXI     H,DEV1
   042.214  377 203     00254           SCALL   .DMNMS
   042.216  041 074 051 00255           LXI     H,DEV2
   042.221  377 203     00256           SCALL   .DMNMS
   042.223  041 101 051 00257           LXI     H,DEV3
   042.226  377 203     00258           SCALL   .DMNMS
                        00259   *
   042.230  315 236 042 00260           CALL    SINT
                        00261   *
   042.233  303 141 044 00262           JMP     BEGIN










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page    2

                        00263   *
                        00264   * SETUP LPT PORT FOR XXXX,8N2
                        00265   *
   042.236              00266   SINT    EQU     *
   042.236  257         00267           XRA     A
   042.237  323 343     00268           OUT     LCNTL4
   042.241  323 341     00269           OUT     IER4
   042.243  323 344     00270           OUT     MCNTL4
   042.245  075         00271           DCR     A
   042.246  323 343     00272           OUT     LCNTL4
   042.250  076 003     00273           MVI     A,BAUDIV
   042.252  323 340     00274           OUT     DVL4
   042.254  257         00275           XRA     A
   042.255  323 341     00276           OUT     DVH4
   042.257  076 007     00277           MVI     A,07H
   042.261  323 343     00278           OUT     LCNTL4
   042.263  333 345     00279           IN      LSTAT4
   042.265  333 340     00280           IN      RX4
   042.267  311         00281           RET
                        00282   *
                        00283   * SEND A CHAR IN (A) TO THE LP PORT (340Q)
                        00284   *
   042.270  365         00285   CHROUT  PUSH    PSW
   042.271  333 345     00286   CHRO4   IN      LSTAT4
   042.273  346 140     00287           ANI     60H
   042.275  376 140     00288           CPI     60H
   042.277  302 271 042 00289           JNZ     CHRO4
   042.302  361         00290           POP     PSW
   042.303  323 340     00291           OUT     TX4
   042.305  311         00292           RET
                        00293   *
                        00294   * READ A CHAR FROM THE LP PORT (340Q)
                        00295   *
   042.306  333 345     00296   CHRIN   IN      LSTAT4
   042.310  037         00297           RAR
   042.311  322 306 042 00298           JNC     CHRIN
   042.314  333 340     00299           IN      RX4
   042.316  311         00300           RET
                        00301   *
   042.317  333 345     00302   CHRRDY  IN      LSTAT4
   042.321  037         00303           RAR
   042.322  311         00304           RET                     Returns NC = no char, C = char ready
                        00305   * DIRECT OUT TO CONSOLE PORT
   042.323  365         00306   OUT350  PUSH    PSW
   042.324  333 355     00307   OUT35A  IN      LSTAT5
   042.326  346 140     00308           ANI     60H
   042.330  376 140     00309           CPI     60H
   042.332  302 324 042 00310           JNZ     OUT35A
   042.335  361         00311           POP     PSW
   042.336  323 350     00312           OUT     TX5
   042.340  311         00313           RET
                        00314   *
   042.341              00315   ZEROMEM EQU     *
   042.341  257         00316           XRA     A
   042.342  167         00317           MOV     M,A
   042.343  043         00318           INX     H
   042.344  033         00319           DCX     D










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page    3

   042.345  173         00320           MOV     A,E
   042.346  262         00321           ORA     D
   042.347  302 341 042 00322           JNZ     ZEROMEM
   042.352  311         00323           RET
                        00324   * FLIP LATCH TO COMMAND MODE
   042.353              00325   H37CMD  EQU     *
   042.353  076 000     00326           MVI     A,CON.CD
   042.355  323 171     00327           OUT     DK.INT
   042.357  311         00328           RET
                        00329   * FLIP LATCH TO SECTOR/TRACK MODE
   042.360              00330   H37TRK  EQU     *
   042.360  076 001     00331           MVI     A,CON.ST
   042.362  323 171     00332           OUT     DK.INT
   042.364  311         00333           RET
                        00334   *
   042.365              00335   BITS    EQU     *
   042.365  305         00336           PUSH    B
   042.366  365         00337           PUSH    PSW
   042.367  076 200     00338           MVI     A,10000000B
   042.371  004         00339           INR     B
   042.372  007         00340   BITS1   RLC
   042.373  005         00341           DCR     B
   042.374  302 372 042 00342           JNZ     BITS1
   042.377  117         00343           MOV     C,A
   043.000  361         00344           POP     PSW
   043.001  261         00345           ORA     C
   043.002  301         00346           POP     B
   043.003  311         00347           RET
                        00348   * INT4 ROUTINE
   043.004              00349   MYINT   EQU     *
   043.004  333 172     00350           IN      FD.STAT
   043.006  341         00351           POP     H
   043.007  052 067 040 00352           LHLD    BLKICW
   043.012  373         00353           EI
   043.013  351         00354           PCHL
                        00355   *
   043.014              00356   RSTBSY  EQU     *
   043.014  076 320     00357           MVI     A,FDC.FI
   043.016  323 172     00358           OUT     FD.CMD
   043.020  076 001     00359           MVI     A,1
   043.022  315 053 000 00360           CALL    DLY
   043.025  333 172     00361           IN      FD.STAT
   043.027  311         00362           RET
                        00363   * DISK DRIVE UNIT TO WD1797 BITS
   043.030              00364   UNIBITS EQU     *
   043.030  072 061 041 00365           LDA     AIO.UNI
   043.033  306 004     00366           ADI     4
   043.035  107         00367           MOV     B,A
   043.036  257         00368           XRA     A
   043.037  315 365 042 00369           CALL    BITS
   043.042  311         00370           RET
                        00371   * SELECT AIO.UNI
   043.043              00372   SELDRV  EQU     *
   043.043  305         00373           PUSH    B
   043.044  315 353 042 00374           CALL    H37CMD
   043.047  315 062 043 00375           CALL    SETDENS
   043.052  373         00376           EI










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page    4

   043.053  076 226     00377           MVI     A,300/2
   043.055  315 053 000 00378           CALL    DLY
   043.060  301         00379           POP     B
   043.061  311         00380           RET
                        00381   * SET DENSITY FROM (DENS)
   043.062              00382   SETDENS EQU     *
   043.062  315 030 043 00383           CALL    UNIBITS         A=DRIVE BIT
   043.065  366 011     00384           ORI     CON.MO+CON.EI
   043.067  117         00385           MOV     C,A
   043.070  072 112 051 00386           LDA     DENS            CON.MFM OR 0
   043.073  261         00387           ORA     C
   043.074  062 111 051 00388           STA     CONCMD          DS0+CON.MO+CON.EI+CON.MFM
   043.077  323 170     00389           OUT     DK.CON
   043.101  311         00390           RET
                        00391   *
   043.102              00392   SETMFM  EQU     *
   043.102  076 004     00393           MVI     A,CON.MFM
   043.104  062 112 051 00394           STA     DENS
   043.107  303 062 043 00395           JMP     SETDENS
                        00396   *
   043.112              00397   SETFM   EQU     *
   043.112  076 000     00398           MVI     A,0
   043.114  062 112 051 00399           STA     DENS
   043.117  303 062 043 00400           JMP     SETDENS
                        00401   * SWITCH DENSITY FM<->MFM
   043.122              00402   CHGDENS EQU     *
   043.122  072 112 051 00403           LDA     DENS
   043.125  376 004     00404           CPI     CON.MFM
   043.127  312 112 043 00405           JZ      SETFM
   043.132  303 102 043 00406           JMP     SETMFM
                        00407   * DESELECT ALL DRIVES
   043.135              00408   DSLDRV  EQU     *
   043.135  365         00409           PUSH    PSW
   043.136  076 320     00410           MVI     A,FDC.FI
   043.140  323 172     00411           OUT     FD.CMD
   043.142  257         00412           XRA     A
   043.143  323 170     00413           OUT     DK.CON
   043.145  361         00414           POP     PSW
   043.146  311         00415           RET
                        00416   * 40MS DELAY
   043.147              00417   DLY40   EQU     *
   043.147  365         00418           PUSH    PSW
   043.150  305         00419           PUSH    B
   043.151  001 200 014 00420           LXI     B,3200
   043.154  013         00421   DLY40A  DCX     B
   043.155  170         00422           MOV     A,B
   043.156  261         00423           ORA     C
   043.157  302 154 043 00424           JNZ     DLY40A
   043.162  301         00425           POP     B
   043.163  361         00426           POP     PSW
   043.164  311         00427           RET
                        00428   * SET UP INTERRUPT 4 VECTOR
   043.165              00429   SUPINT  EQU     *
   043.165  041 004 043 00430           LXI     H,MYINT
   043.170  042 051 040 00431           SHLD    UIVEC+9+1
   043.173  076 303     00432           MVI     A,MI.JMP
   043.175  062 050 040 00433           STA     UIVEC+9










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page    5

   043.200  311         00434           RET
                        00435   * WAIT HERE UNTIL INTERRUPT JUMPS TO BLKICW
   043.201              00436   WAITINT EQU     *
   043.201  303 201 043 00437           JMP     WAITINT
                        00438   * C=TRACK
   043.204              00439   STPIN   EQU     *
   043.204  315 043 043 00440           CALL    SELDRV
   043.207  041 224 043 00441           LXI     H,STPI2
   043.212  042 067 040 00442           SHLD    BLKICW
   043.215              00443   STPI1   EQU     *
   043.215  076 102     00444           MVI     A,FDC.STI+FDF.S20
   043.217  323 172     00445           OUT     FD.CMD
   043.221  303 201 043 00446           JMP     WAITINT
   043.224              00447   STPI2   EQU     *
   043.224  072 106 051 00448           LDA     CURTRK
   043.227  074         00449           INR     A
   043.230  062 106 051 00450           STA     CURTRK
   043.233  271         00451           CMP     C
   043.234  302 215 043 00452           JNZ     STPI1
   043.237  315 147 043 00453           CALL    DLY40
   043.242  311         00454           RET
                        00455   * C=TRACK
   043.243              00456   STPOUT  EQU     *
   043.243  315 043 043 00457           CALL    SELDRV
   043.246  072 106 051 00458           LDA     CURTRK
   043.251  267         00459           ORA     A
   043.252  312 311 043 00460           JZ      SEEK0
   043.255  041 272 043 00461           LXI     H,STPO2
   043.260  042 067 040 00462           SHLD    BLKICW
   043.263              00463   STPO1   EQU     *
   043.263  076 142     00464           MVI     A,FDC.STO+FDF.S20
   043.265  323 172     00465           OUT     FD.CMD
   043.267  303 201 043 00466           JMP     WAITINT
   043.272              00467   STPO2   EQU     *
   043.272  072 106 051 00468           LDA     CURTRK
   043.275  075         00469           DCR     A
   043.276  062 106 051 00470           STA     CURTRK
   043.301  271         00471           CMP     C
   043.302  302 263 043 00472           JNZ     STPO1
   043.305  315 147 043 00473           CALL    DLY40
   043.310  311         00474           RET
                        00475   * SEEK TO TRACK 0
   043.311              00476   SEEK0   EQU     *
   043.311  315 043 043 00477           CALL    SELDRV
   043.314  257         00478           XRA     A
   043.315  062 106 051 00479           STA     CURTRK
   043.320  041 335 043 00480           LXI     H,SEEKD
   043.323  042 067 040 00481           SHLD    BLKICW
   043.326  076 002     00482           MVI     A,FDC.RST+FDF.S20
   043.330  323 172     00483           OUT     FD.CMD
   043.332  303 201 043 00484           JMP     WAITINT
   043.335              00485   SEEKD   EQU     *
   043.335  036 012     00486           MVI     E,10            STEP IN 10 TIMES
   043.337  041 354 043 00487           LXI     H,SEEKD2
   043.342  042 067 040 00488           SHLD    BLKICW
   043.345              00489   SEEKD1  EQU     *
   043.345  076 102     00490           MVI     A,FDC.STI+FDF.S20










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page    6

   043.347  323 172     00491           OUT     FD.CMD
   043.351  303 201 043 00492           JMP     WAITINT
   043.354              00493   SEEKD2  EQU     *
   043.354  035         00494           DCR     E
   043.355  302 345 043 00495           JNZ     SEEKD1
                        00496   * DOUBLE RESTORE
   043.360  041 375 043 00497           LXI     H,SEEKD3
   043.363  042 067 040 00498           SHLD    BLKICW
   043.366  076 002     00499           MVI     A,FDC.RST+FDF.S20
   043.370  323 172     00500           OUT     FD.CMD
   043.372  303 201 043 00501           JMP     WAITINT
   043.375              00502   SEEKD3  EQU     *
   043.375  315 147 043 00503           CALL    DLY40           HEAD SETTLE TIME
   044.000  346 004     00504           ANI     FDS.TK0
   044.002  300         00505           RNZ
   044.003  067         00506           STC
   044.004  311         00507           RET
                        00508   * C=TRK (STEP IN OR OUT TO REACH TARGET)
   044.005              00509   SEEKTO  EQU     *
   044.005  315 360 042 00510           CALL    H37TRK
   044.010  171         00511           MOV     A,C
   044.011  323 173     00512           OUT     FD.TRK          SET TRACK REGISTER
   044.013  072 106 051 00513           LDA     CURTRK
   044.016  221         00514           SUB     C
   044.017  310         00515           RZ                      ALREADY AT TRK C
   044.020  332 204 043 00516           JC      STPIN
   044.023  303 243 043 00517           JMP     STPOUT
                        00518   * DE=BUFFER - READ TRACK INTO BUFFER
   044.026              00519   READLP  EQU     *
   044.026  001 000 000 00520           LXI     B,0             TOTAL BYTES READ
   044.031  041 074 044 00521           LXI     H,READL2        RETURN ADDRESS
   044.034  042 067 040 00522           SHLD    BLKICW
   044.037  315 353 042 00523           CALL    H37CMD
   044.042  072 111 051 00524           LDA     CONCMD
   044.045  366 002     00525           ORI     CON.DRQ
   044.047  323 170     00526           OUT     DK.CON
                        00527   * RDS=READ SECTOR
                        00528   * DLF=15MS DELAY
                        00529   * MRF=READ TO END OF TRACK
                        00530   * SLF=SECTOR LEN SHIFT (128,256,512,1024)
                        00531   * SS1=SIDE 1 FLAG
   044.051  257         00532           XRA     A
   044.052  072 110 051 00533           LDA     SIDE            0=SIDE 1,1=SIDE 2
   044.055  027         00534           RAL                     IF A=1 THEN RAL=FDF.SS1
   044.056  366 234     00535           ORI     FDC.RDS+FDF.DLF+FDF.MRF+FDF.SLF
   044.060  323 172     00536           OUT     FD.CMD
   044.062  041 065 044 00537           LXI     H,READL1
   044.065              00538   READL1  EQU     *               LOOP UNTIL IRQ4
   044.065  166         00539           HLT                     WAIT FOR DRQ
   044.066  333 173     00540           IN      FD.DAT
   044.070  022         00541           STAX    D
   044.071  023         00542           INX     D
   044.072  003         00543           INX     B
   044.073  351         00544           PCHL                    LOOP BACK TO READL1
   044.074              00545   READL2  EQU     *
   044.074  076 010     00546           MVI     A,CON.MO
   044.076  323 170     00547           OUT     DK.CON










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page    7

   044.100  151         00548           MOV     L,C
   044.101  140         00549           MOV     H,B
   044.102  042 114 051 00550           SHLD    RDCNT
   044.105  315 360 042 00551           CALL    H37TRK
   044.110  333 172     00552           IN      FD.SEC
   044.112  075         00553           DCR     A
   044.113  062 113 051 00554           STA     SPERT
   044.116  267         00555           ORA     A               SECTORS PER TRACK == 0?
   044.117  300         00556           RNZ                     NO ERRORS
   044.120  067         00557           STC                     ERROR, SET CARRY FLAG
   044.121  311         00558           RET
                        00559   * B=SEC (1-255),C=TRK (0-255)
   044.122              00560   READS   EQU     *
   044.122  315 360 042 00561           CALL    H37TRK
   044.125  170         00562           MOV     A,B
   044.126  323 172     00563           OUT     FD.SEC          SET SECTOR REGISTER
   044.130  315 005 044 00564           CALL    SEEKTO
   044.133  021 232 051 00565           LXI     D,SECBUF
   044.136  303 026 044 00566           JMP     READLP
                        00567   *
                        00568   * IMAGER COMMANDS
                        00569   * R = READ IMAGE SEND TO HOST
                        00570   * W = WRITE IMAGE FROM HOST
                        00571   * 0 = DK0
                        00572   * 1 = DK1
                        00573   * 4 = 1S40T
                        00574   * 5 = 2S40T
                        00575   * 6 = 1S80T
                        00576   * 7 = 2S80T
                        00577   * A = SIDE 1
                        00578   * B = SIDE 2
                        00579   * E = EXAMINE TRACK
                        00580   * Q = QUERY DISK TYPE
                        00581   * T = QUERY TRACK HEADER
                        00582   *
   044.141              00583   BEGIN   EQU     *
   044.141  315 136 031 00584           CALL    $TYPTX
   044.144  012 110 063 00585           DB      0AH,'H37IMGR 2021.09.30 BY LES BIRD',0AH
   044.204  123 117 106 00586           DB      'SOFT SECTOR DISK IMAGING PROGRAM',0AH
   044.245  104 122 111 00587           DB      'DRIVE CONFIGURATION SHOULD BE AS FOLLOWS:',0AH
   044.317  104 113 060 00588           DB      'DK0: DS 40 TRACK',0AH
   044.340  104 113 061 00589           DB      'DK1: DS 80 TRACK',8AH
   044.361  315 353 042 00590           CALL    H37CMD
   044.364  315 014 043 00591           CALL    RSTBSY
   044.367  315 165 043 00592           CALL    SUPINT
   044.372  257         00593           XRA     A               SET DRIVE UNIT TO 0
   044.373  062 061 041 00594           STA     AIO.UNI
   044.376  074         00595           INR     A
   044.377  062 117 051 00596           STA     NUMSID          SINGLE SIDE IS DEFAULT
   045.002  076 050     00597           MVI     A,40
   045.004  062 116 051 00598           STA     NUMTRK          40 TRACK IS DEFAULT
   045.007  315 043 043 00599           CALL    SELDRV
   045.012  315 311 043 00600           CALL    SEEK0           SEEK TRACK 0
   045.015              00601   BEGLP   EQU     *
   045.015  315 136 031 00602           CALL    $TYPTX
   045.020  127 101 111 00603           DB      'WAITING FOR COMMAND:',80H
   045.045  315 135 043 00604           CALL    DSLDRV










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page    8

   045.050              00605   BEGLP1  EQU     *
   045.050  315 306 042 00606           CALL    CHRIN           WAIT FOR COMMAND FROM LP PORT
   045.053  376 122     00607           CPI     'R'             READ DISK IMAGE
   045.055  312 171 045 00608           JZ      CMDRDI
   045.060  376 127     00609           CPI     'W'
   045.062  312 027 046 00610           JZ      CMDWDI
   045.065  376 060     00611           CPI     '0'
   045.067  312 030 046 00612           JZ      SETDK0
   045.072  376 061     00613           CPI     '1'
   045.074  312 062 046 00614           JZ      SETDK1
   045.077  376 063     00615           CPI     '3'             IDENTIFY AS H37IMGR
   045.101  312 115 046 00616           JZ      ISH37
   045.104  376 064     00617           CPI     '4'
   045.106  312 163 046 00618           JZ      SET1S4
   045.111  376 065     00619           CPI     '5'
   045.113  312 230 046 00620           JZ      SET2S4
   045.116  376 066     00621           CPI     '6'
   045.120  312 275 046 00622           JZ      SET1S8
   045.123  376 067     00623           CPI     '7'
   045.125  312 343 046 00624           JZ      SET2S8
   045.130  376 121     00625           CPI     'Q'
   045.132  312 011 047 00626           JZ      QUERY
   045.135  376 124     00627           CPI     'T'
   045.137  312 011 050 00628           JZ      GETTRK
   045.142  376 105     00629           CPI     'E'
   045.144  312 163 050 00630           JZ      EXMTRK
   045.147  376 101     00631           CPI     'A'
   045.151  312 206 050 00632           JZ      SETSID1
   045.154  376 102     00633           CPI     'B'
   045.156  312 236 050 00634           JZ      SETSID2
   045.161  076 077     00635           MVI     A,'?'
   045.163  315 270 042 00636           CALL    CHROUT
   045.166  303 050 045 00637           JMP     BEGLP1
                        00638   * CMD READ DISK IMAGE
   045.171              00639   CMDRDI  EQU     *
   045.171  315 136 031 00640           CALL    $TYPTX
   045.174  122 105 101 00641           DB      'READ DISK IMAGE',8AH
   045.214  315 043 043 00642           CALL    SELDRV
   045.217  257         00643           XRA     A
   045.220  062 110 051 00644           STA     SIDE            INITIALIZE SIDE
   045.223  001 000 001 00645           LXI     B,0100H         START SECTOR 1, TRACK 0
   045.226              00646   CMDRD1  EQU     *
   045.226  315 306 042 00647           CALL    CHRIN           WAIT FOR REQUEST
   045.231  376 122     00648           CPI     'R'
   045.233  302 015 045 00649           JNZ     BEGLP           NOT 'R' SO PROBABLY ABORT
   045.236  305         00650           PUSH    B
   045.237  076 122     00651           MVI     A,'R'
   045.241  315 323 042 00652           CALL    OUT350
                        00653   *
   045.244  315 122 044 00654           CALL    READS           READ TRACK
                        00655   *
   045.247  076 010     00656           MVI     A,08H
   045.251  315 323 042 00657           CALL    OUT350
   045.254  076 123     00658           MVI     A,'S'
   045.256  315 323 042 00659           CALL    OUT350          SHOW SENDING BUFFER
                        00660   *
   045.261  315 355 045 00661           CALL    SENDT           SEND TRACK BUFFER










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page    9

                        00662   *
   045.264  076 010     00663           MVI     A,08H
   045.266  315 323 042 00664           CALL    OUT350
   045.271  076 052     00665           MVI     A,'*'
   045.273  315 323 042 00666           CALL    OUT350          SHOW TRACK SENT
   045.276  301         00667           POP     B               GET SEC,TRK
   045.277  072 117 051 00668           LDA     NUMSID          1 OR 2
   045.302  075         00669           DCR     A
   045.303  312 324 045 00670           JZ      CMDRD2          SINGLE SIDED
   045.306  072 110 051 00671           LDA     SIDE            0 OR 1
   045.311  267         00672           ORA     A
   045.312  302 324 045 00673           JNZ     CMDRD2          FINISHED SIDE 2
   045.315  074         00674           INR     A
   045.316  062 110 051 00675           STA     SIDE
   045.321  303 226 045 00676           JMP     CMDRD1          READ SIDE 2
   045.324              00677   CMDRD2  EQU     *
   045.324  257         00678           XRA     A
   045.325  062 110 051 00679           STA     SIDE            SET SIDE 1
   045.330  014         00680           INR     C
   045.331  072 116 051 00681           LDA     NUMTRK
   045.334  271         00682           CMP     C
   045.335  302 226 045 00683           JNZ     CMDRD1
   045.340  076 015     00684           MVI     A,0DH
   045.342  315 323 042 00685           CALL    OUT350
   045.345  076 012     00686           MVI     A,0AH
   045.347  315 323 042 00687           CALL    OUT350
   045.352  303 015 045 00688           JMP     BEGLP
                        00689   * SEND TRACK DATA TO 340Q
   045.355              00690   SENDT   EQU     *
   045.355  052 114 051 00691           LHLD    RDCNT
   045.360  175         00692           MOV     A,L
   045.361  315 270 042 00693           CALL    CHROUT
   045.364  174         00694           MOV     A,H
   045.365  315 270 042 00695           CALL    CHROUT
   045.370  072 113 051 00696           LDA     SPERT
   045.373  315 270 042 00697           CALL    CHROUT
   045.376  175         00698           MOV     A,L
   045.377  264         00699           ORA     H
   046.000  312 021 046 00700           JZ      SENDT2
   046.003  021 232 051 00701           LXI     D,SECBUF
   046.006              00702   SENDT1  EQU     *
   046.006  032         00703           LDAX    D
   046.007  315 270 042 00704           CALL    CHROUT
   046.012  023         00705           INX     D
   046.013  053         00706           DCX     H
   046.014  175         00707           MOV     A,L
   046.015  264         00708           ORA     H
   046.016  302 006 046 00709           JNZ     SENDT1
   046.021              00710   SENDT2  EQU     *
   046.021  076 122     00711           MVI     A,'R'
   046.023  315 270 042 00712           CALL    CHROUT          HANDSHAKE
   046.026  311         00713           RET
                        00714   * COMMAND WRITE DISK IMAGE
   046.027              00715   CMDWDI  EQU     *
   046.027  311         00716           RET
                        00717   * COMMAND SET DRIVE 0
   046.030              00718   SETDK0  EQU     *










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page   10

   046.030  365         00719           PUSH    PSW
   046.031  315 136 031 00720           CALL    $TYPTX
   046.034  123 105 124 00721           DB      'SET DK0',8AH
   046.044  257         00722           XRA     A
   046.045  062 061 041 00723           STA     AIO.UNI
   046.050  315 311 043 00724           CALL    SEEK0
   046.053  361         00725           POP     PSW
   046.054  315 270 042 00726           CALL    CHROUT          HANDSHAKE
   046.057  303 015 045 00727           JMP     BEGLP
                        00728   * COMMAND SET DRIVE 1
   046.062              00729   SETDK1  EQU     *
   046.062  365         00730           PUSH    PSW
   046.063  315 136 031 00731           CALL    $TYPTX
   046.066  123 105 124 00732           DB      'SET DK1',8AH
   046.076  076 001     00733           MVI     A,1
   046.100  062 061 041 00734           STA     AIO.UNI
   046.103  315 311 043 00735           CALL    SEEK0
   046.106  361         00736           POP     PSW
   046.107  315 270 042 00737           CALL    CHROUT
   046.112  303 015 045 00738           JMP     BEGLP
                        00739   * H37 IMAGER IDENTIFIER
   046.115              00740   ISH37   EQU     *
   046.115  315 270 042 00741           CALL    CHROUT
   046.120  315 136 031 00742           CALL    $TYPTX
   046.123  111 104 105 00743           DB      'IDENTIFY AS H37IMGR',8AH
   046.147  303 015 045 00744           JMP     BEGLP
                        00745   * SET DRIVE PARAMETERS (SIDES,TRACKS)
   046.152              00746   SETPAR  EQU     *
   046.152  170         00747           MOV     A,B
   046.153  062 117 051 00748           STA     NUMSID
   046.156  171         00749           MOV     A,C
   046.157  062 116 051 00750           STA     NUMTRK
   046.162  311         00751           RET
                        00752   * COMMAND SET SS 40 TRACK
   046.163              00753   SET1S4  EQU     *
   046.163  365         00754           PUSH    PSW
   046.164  315 136 031 00755           CALL    $TYPTX
   046.167  123 105 124 00756           DB      'SET SS 40 TRACK',8AH
   046.207  001 050 001 00757           LXI     B,0128H
   046.212  315 152 046 00758           CALL    SETPAR
   046.215  257         00759           XRA     A
   046.216  062 061 041 00760           STA     AIO.UNI
   046.221  361         00761           POP     PSW
   046.222  315 270 042 00762           CALL    CHROUT
   046.225  303 015 045 00763           JMP     BEGLP
                        00764   * COMMAND SET DS 40 TRACK
   046.230              00765   SET2S4  EQU     *
   046.230  365         00766           PUSH    PSW
   046.231  315 136 031 00767           CALL    $TYPTX
   046.234  123 105 124 00768           DB      'SET DS 40 TRACK',8AH
   046.254  001 050 002 00769           LXI     B,0228H
   046.257  315 152 046 00770           CALL    SETPAR
   046.262  257         00771           XRA     A
   046.263  062 061 041 00772           STA     AIO.UNI
   046.266  361         00773           POP     PSW
   046.267  315 270 042 00774           CALL    CHROUT
   046.272  303 015 045 00775           JMP     BEGLP










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page   11

                        00776   * COMMAND SET SS 80 TRACK
   046.275              00777   SET1S8  EQU     *
   046.275  365         00778           PUSH    PSW
   046.276  315 136 031 00779           CALL    $TYPTX
   046.301  123 105 124 00780           DB      'SET SS 80 TRACK',8AH
   046.321  001 120 001 00781           LXI     B,0150H
   046.324  315 152 046 00782           CALL    SETPAR
   046.327  076 001     00783           MVI     A,1
   046.331  062 061 041 00784           STA     AIO.UNI
   046.334  361         00785           POP     PSW
   046.335  315 270 042 00786           CALL    CHROUT
   046.340  303 015 045 00787           JMP     BEGLP
                        00788   * COMMAND SET DS 80 TRACK
   046.343              00789   SET2S8  EQU     *
   046.343  365         00790           PUSH    PSW
   046.344  315 136 031 00791           CALL    $TYPTX
   046.347  123 105 124 00792           DB      'SET DS 80 TRACK',8AH
   046.367  001 120 002 00793           LXI     B,0250H
   046.372  315 152 046 00794           CALL    SETPAR
   046.375  076 001     00795           MVI     A,1
   046.377  062 061 041 00796           STA     AIO.UNI
   047.002  361         00797           POP     PSW
   047.003  315 270 042 00798           CALL    CHROUT
   047.006  303 015 045 00799           JMP     BEGLP
                        00800   * COMMAND QUERY DISK TYPE
   047.011              00801   QUERY   EQU     *
   047.011  315 270 042 00802           CALL    CHROUT
   047.014  315 136 031 00803           CALL    $TYPTX
   047.017  121 125 105 00804           DB      'QUERY DISK TYPE',8AH
   047.037  001 000 000 00805           LXI     B,0             SEC,TRK=0
   047.042  315 155 047 00806           CALL    QUERY1
   047.045  315 053 047 00807           CALL    QUERYR
   047.050  303 015 045 00808           JMP     BEGLP
   047.053              00809   QUERYR  EQU     *
   047.053  072 113 051 00810           LDA     SPERT           SECTORS PER TRACK
   047.056  315 270 042 00811           CALL    CHROUT
                        00812   * READ ADDRESS RESULTS
   047.061  072 120 051 00813           LDA     QTRK            TRACK
   047.064  315 270 042 00814           CALL    CHROUT
   047.067  072 121 051 00815           LDA     QSID            SIDE
   047.072  315 270 042 00816           CALL    CHROUT
   047.075  072 122 051 00817           LDA     QSEC            SECTOR
   047.100  315 270 042 00818           CALL    CHROUT
   047.103  072 123 051 00819           LDA     QSECL           SECTOR LENGTH
   047.106  315 270 042 00820           CALL    CHROUT
   047.111  072 124 051 00821           LDA     QCRC1           CRC 1
   047.114  315 270 042 00822           CALL    CHROUT
   047.117  072 125 051 00823           LDA     QCRC2           CRC 2
   047.122  315 270 042 00824           CALL    CHROUT
                        00825   * DISK PARAMETERS
   047.125  072 117 051 00826           LDA     NUMSID          NUM SIDES
   047.130  315 270 042 00827           CALL    CHROUT
   047.133  052 114 051 00828           LHLD    RDCNT
   047.136  175         00829           MOV     A,L             RDCNT LOW BYTE
   047.137  315 270 042 00830           CALL    CHROUT
   047.142  174         00831           MOV     A,H             RDCNT HIGH BYTE
   047.143  315 270 042 00832           CALL    CHROUT










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page   12

   047.146  072 112 051 00833           LDA     DENS            DENSITY CON.MFM OR 0
   047.151  315 270 042 00834           CALL    CHROUT
   047.154  311         00835           RET
                        00836   * READ/DETERMINE DISK TYPE
   047.155              00837   QUERY1  EQU     *
   047.155  257         00838           XRA     A
   047.156  062 113 051 00839           STA     SPERT
   047.161  076 004     00840           MVI     A,CON.MFM       TEST MFM FIRST
   047.163  062 112 051 00841           STA     DENS
   047.166  315 043 043 00842           CALL    SELDRV
   047.171  021 000 040 00843           LXI     D,BUFSIZ
   047.174  041 232 051 00844           LXI     H,SECBUF
   047.177  315 341 042 00845           CALL    ZEROMEM
   047.202              00846   QUERYL  EQU     *
   047.202  076 002     00847           MVI     A,2
   047.204  062 117 051 00848           STA     NUMSID          DOUBLE SIDED DEFAULT
   047.207  075         00849           DCR     A
   047.210  062 110 051 00850           STA     SIDE
   047.213  107         00851           MOV     B,A             SECTOR 1, C=TRK
   047.214  315 122 044 00852           CALL    READS           TEST READ SIDE 2
   047.217  365         00853           PUSH    PSW
   047.220  257         00854           XRA     A
   047.221  062 110 051 00855           STA     SIDE
   047.224  361         00856           POP     PSW
   047.225  322 325 047 00857           JNC     QUERYS          GOOD DOUBLE SIDE READ
   047.230  076 001     00858           MVI     A,1
   047.232  062 117 051 00859           STA     NUMSID          SINGLE SIDED DISK
   047.235  107         00860           MOV     B,A
   047.236  072 106 051 00861           LDA     CURTRK
   047.241  117         00862           MOV     C,A
   047.242  315 122 044 00863           CALL    READS           READ A TRACK FILL SPERT+RDCNT
   047.245  322 325 047 00864           JNC     QUERYS          GOOD SINGLE SIDE READ
   047.250  072 112 051 00865           LDA     DENS
   047.253  376 004     00866           CPI     CON.MFM
   047.255  302 372 047 00867           JNZ     QUERY3          FAILED MFM AND FM
   047.260  315 136 031 00868           CALL    $TYPTX
   047.263  103 110 105 00869           DB      'CHECKING SINGLE DENSITY',8AH
   047.313  315 122 043 00870           CALL    CHGDENS         MIGHT BE FM
   047.316  072 106 051 00871           LDA     CURTRK
   047.321  117         00872           MOV     C,A
   047.322  303 202 047 00873           JMP     QUERYL
                        00874   * JUST READ THE HEADER
   047.325              00875   QUERYS  EQU     *
   047.325  315 353 042 00876           CALL    H37CMD
   047.330  041 372 047 00877           LXI     H,QUERY3
   047.333  042 067 040 00878           SHLD    BLKICW
   047.336  072 111 051 00879           LDA     CONCMD
   047.341  366 002     00880           ORI     CON.DRQ
   047.343  323 170     00881           OUT     DK.CON
   047.345  001 000 000 00882           LXI     B,0
   047.350  021 120 051 00883           LXI     D,QBUF
   047.353  041 363 047 00884           LXI     H,QUERY2
   047.356  257         00885           XRA     A
   047.357  366 304     00886           ORI     FDC.RDA+FDF.DLF
   047.361  323 172     00887           OUT     FD.CMD
   047.363              00888   QUERY2  EQU     *               LOOP UNTIL IRQ4
   047.363  166         00889           HLT                     WAIT FOR DRQ










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page   13

   047.364  333 173     00890           IN      FD.DAT
   047.366  022         00891           STAX    D
   047.367  023         00892           INX     D
   047.370  003         00893           INX     B
   047.371  351         00894           PCHL
   047.372              00895   QUERY3  EQU     *
   047.372  076 320     00896           MVI     A,FDC.FI
   047.374  323 172     00897           OUT     FD.CMD
   047.376  333 173     00898           IN      FD.DAT
   050.000  076 010     00899           MVI     A,CON.MO
   050.002  323 170     00900           OUT     DK.CON
   050.004  171         00901           MOV     A,C
   050.005  260         00902           ORA     B
   050.006  300         00903           RNZ
   050.007  067         00904           STC
   050.010  311         00905           RET
                        00906   * GET TRACK HEADER
   050.011              00907   GETTRK  EQU     *
   050.011  315 270 042 00908           CALL    CHROUT          HANDSHAKE
   050.014  315 306 042 00909           CALL    CHRIN           GET TRACK TO CHECK
   050.017  117         00910           MOV     C,A             STORE TRACK
   050.020  305         00911           PUSH    B
   050.021  315 136 031 00912           CALL    $TYPTX
   050.024  121 125 105 00913           DB      'QUERY TRACK',8AH
   050.040  301         00914           POP     B
   050.041  315 052 050 00915           CALL    GETTR0
   050.044  315 053 047 00916           CALL    QUERYR
   050.047  303 015 045 00917           JMP     BEGLP
   050.052              00918   GETTR0  EQU     *
   050.052  315 102 043 00919           CALL    SETMFM
   050.055              00920   GETTR1  EQU     *
   050.055  315 325 047 00921           CALL    QUERYS
   050.060  322 162 050 00922           JNC     GETTR3
   050.063  072 112 051 00923           LDA     DENS
   050.066  267         00924           ORA     A
   050.067  312 132 050 00925           JZ      GETTR2
   050.072  315 136 031 00926           CALL    $TYPTX
   050.075  124 122 131 00927           DB      'TRY SINGLE DENSITY',8AH
   050.120  315 112 043 00928           CALL    SETFM
   050.123  072 106 051 00929           LDA     CURTRK
   050.126  117         00930           MOV     C,A
   050.127  303 055 050 00931           JMP     GETTR1
   050.132              00932   GETTR2  EQU     *
   050.132  315 136 031 00933           CALL    $TYPTX
   050.135  104 111 123 00934           DB      'DISK NOT RECOGNIZED',8AH
   050.161  067         00935           STC
   050.162              00936   GETTR3  EQU     *
   050.162  311         00937           RET
                        00938   *
   050.163              00939   EXMTRK  EQU     *
   050.163  315 270 042 00940           CALL    CHROUT          HANDSHAKE
   050.166  315 306 042 00941           CALL    CHRIN
   050.171  117         00942           MOV     C,A             TRACK TO READ
   050.172  315 155 047 00943           CALL    QUERY1
   050.175  315 355 045 00944           CALL    SENDT
   050.200  315 053 047 00945           CALL    QUERYR
   050.203  303 015 045 00946           JMP     BEGLP










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page   14

                        00947   *
   050.206              00948   SETSID1 EQU     *
   050.206  315 270 042 00949           CALL    CHROUT
   050.211  315 136 031 00950           CALL    $TYPTX
   050.214  123 105 124 00951           DB      'SET SIDE 1',8AH
   050.227  257         00952           XRA     A
   050.230  062 110 051 00953           STA     SIDE
   050.233  303 015 045 00954           JMP     BEGLP
                        00955   *
   050.236              00956   SETSID2 EQU     *
   050.236  315 270 042 00957           CALL    CHROUT
   050.241  315 136 031 00958           CALL    $TYPTX
   050.244  123 105 124 00959           DB      'SET SIDE 2',8AH
   050.257  076 001     00960           MVI     A,1
   050.261  062 110 051 00961           STA     SIDE
   050.264  303 015 045 00962           JMP     BEGLP
                        00963   *
   050.267              00964   FMTTRK  EQU     *
   050.267  072 112 051 00965           LDA     DENS
   050.272  267         00966           ORA     A
   050.273  302 302 050 00967           JNZ     FMTDD
                        00968   * SINGLE DENSITY FORMAT
   050.276              00969   FMTSD   EQU     *
   050.276  021 172 051 00970           LXI     D,SDTT
   050.301  311         00971           RET
                        00972   * DOUBLE DENSITY FORMAT
   050.302              00973   FMTDD   EQU     *
   050.302  076 020     00974           MVI     A,16
   050.304  062 113 051 00975           STA     SPERT
   050.307  076 001     00976           MVI     A,1
   050.311  062 142 051 00977           STA     DDSEC           START SECTOR 1
   050.314  072 106 051 00978           LDA     CURTRK
   050.317  062 136 051 00979           STA     DDTRK
   050.322  072 110 051 00980           LDA     SIDE
   050.325  062 140 051 00981           STA     DDSID
   050.330  021 232 051 00982           LXI     D,SECBUF
   050.333  041 126 051 00983           LXI     H,DDTT
   050.336              00984   FMTDD1  EQU     *
   050.336  176         00985           MOV     A,M
   050.337  043         00986           INX     H
   050.340  116         00987           MOV     C,M
   050.341  043         00988           INX     H
   050.342  261         00989           ORA     C
   050.343  312 354 050 00990           JZ      FMTDD2          END OF SECTOR DATA
   050.346  315 060 051 00991           CALL    WDAT
   050.351  303 336 050 00992           JMP     FMTDD1
   050.354              00993   FMTDD2  EQU     *
   050.354  072 113 051 00994           LDA     SPERT
   050.357  074         00995           INR     A
   050.360  117         00996           MOV     C,A
   050.361  072 142 051 00997           LDA     DDSEC
   050.364  074         00998           INR     A
   050.365  062 142 051 00999           STA     DDSEC
   050.370  271         01000           CMP     C
   050.371  302 336 050 01001           JNZ     FMTDD1
                        01002   * WRITE THE TRACK
   050.374              01003   WRTTRK  EQU     *










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page   15

   050.374  072 111 051 01004           LDA     CONCMD
   050.377  366 002     01005           ORI     CON.DRQ
   051.001  323 170     01006           OUT     DK.CON
   051.003  076 364     01007           MVI     A,FDC.WTT+FDF.DLF
   051.005  157         01008           MOV     L,A
   051.006  072 110 051 01009           LDA     SIDE
   051.011  267         01010           ORA     A
   051.012  312 020 051 01011           JZ      WRTTR1
   051.015  076 002     01012           MVI     A,FDF.SS1
   051.017  265         01013           ORA     L
   051.020              01014   WRTTR1  EQU     *
   051.020  041 044 051 01015           LXI     H,WRTTR3
   051.023  042 067 040 01016           SHLD    BLKICW
   051.026  041 036 051 01017           LXI     H,WRTTR2
   051.031  021 232 051 01018           LXI     D,SECBUF
   051.034  323 172     01019           OUT     FD.CMD
   051.036              01020   WRTTR2  EQU     *
   051.036  166         01021           HLT
   051.037  032         01022           LDAX    D
   051.040  323 173     01023           OUT     FD.DAT
   051.042  023         01024           INX     D
   051.043  351         01025           PCHL
   051.044              01026   WRTTR3  EQU     *
   051.044  076 226     01027           MVI     A,150           WRITE GATE DELAY
   051.046  075         01028   WRTTR4  DCR     A
   051.047  302 046 051 01029           JNZ     WRTTR4
   051.052  072 111 051 01030           LDA     CONCMD
   051.055  323 170     01031           OUT     DK.CON
   051.057  311         01032           RET
                        01033   *
   051.060  022         01034   WDAT    STAX    D
   051.061  023         01035           INX     D
   051.062  015         01036           DCR     C
   051.063  302 060 051 01037           JNZ     WDAT
   051.066  311         01038           RET
                        01039   *
   051.067  123 131 060 01040   DEV1    DB      'SY0:',0
   051.074  123 131 061 01041   DEV2    DB      'SY1:',0
   051.101  123 131 062 01042   DEV3    DB      'SY2:',0
                        01043   *
   051.106  000         01044   CURTRK  DB      0               0-79
   051.107  000         01045   CURSEC  DB      0               1-16
   051.110  000         01046   SIDE    DB      0               0 OR 1
   051.111  000         01047   CONCMD  DB      0               LAST COMMAND SENT TO DK.CON
   051.112  004         01048   DENS    DB      CON.MFM
                        01049   *
   051.113  000         01050   SPERT   DB      0               SECTORS PER TRACK
   051.114  000 000     01051   RDCNT   DW      0               BYTES READ
   051.116  000         01052   NUMTRK  DB      0               NUM TRACKS (40 OR 80)
   051.117  000         01053   NUMSID  DB      0               NUM SIDES (1 OR 2)
                        01054   *
   051.120              01055   QBUF    EQU     *
   051.120  000         01056   QTRK    DB      0
   051.121  000         01057   QSID    DB      0
   051.122  000         01058   QSEC    DB      0
   051.123  000         01059   QSECL   DB      0
   051.124  000         01060   QCRC1   DB      0










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page   16

   051.125  000         01061   QCRC2   DB      0
                        01062   *
   051.126  116 050     01063   DDTT    DB      04EH,40
   051.130  000 014     01064   DDTTA   DB      0,12
   051.132  365 003     01065           DB      0F5H,3
   051.134  376 001     01066           DB      0FEH,1
   051.136  000 001     01067   DDTRK   DB      0,1
   051.140  000 001     01068   DDSID   DB      0,1
   051.142  000 001     01069   DDSEC   DB      0,1
   051.144  001 001     01070           DB      1,1
   051.146  367 001     01071           DB      0F7H,1
   051.150  116 026     01072           DB      04EH,22
   051.152  000 014     01073           DB      0,12
   051.154  365 003     01074           DB      0F5H,3
   051.156  373 001     01075           DB      0FBH,1
   051.160  345 200     01076   DDDP1   DB      0E5H,128
   051.162  345 200     01077   DDDP2   DB      0E5H,128
   051.164  367 001     01078           DB      0F7H,1
   051.166  116 053     01079           DB      04EH,43
   051.170  000 000     01080           DB      0,0
                        01081
   051.172  377 040     01082   SDTT    DB      0FFH,32
   051.174  000 006     01083   SDTTA   DB      0,6
   051.176  376 001     01084           DB      0FEH,1
   051.200  000 001     01085   SDTRK   DB      0,1
   051.202  000 001     01086   SDSID   DB      0,1
   051.                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page    1

                        00001   *
                        00002   * H37IMGR
                        00003   *
                        00004   * 2021.09.30 LES BIRD
                        00005   * ALSO WORKS FOR PC/Z100 5.25 DISKS (WD179X)
                        00006   *
   042.200              00007           XTEXT   HOSEQU
   042.200              00035           XTEXT   HOSDEF
   000.207              00101           XTEXT   H37DEF
   000.207              00189           XTEXT   HROM
                        00216   *
   040.000              00217   BUFSIZ  EQU     8192            DISK TRACK BUFFER SIZE
   000.014              00218   BAUD96  EQU     0CH             9,600 BAUD
   000.006              00219   BAUD19  EQU     06H             19,200 BAUD
   000.003              00220   BAUD38  EQU     03H             38,400 BAUD
   000.002              00221   BAUD56  EQU     02H             56,000 BAUD
                        00222   *
   000.003              00223   BAUDIV  EQU     03H             19200 BAUD IS DEFAULT
                        00224   *
   000.053              00225   DLY     EQU     53A
   040.037              00226   UIVEC   EQU     40037A          USER INTERRUPT VECTOR
   040.067              00227   BLKICW  EQU     40067A          INTERRUPT RETURN ADDRESS
   041.061              00228   AIO.UNI EQU     41061A          CURRENT DEVICE
                        00229   *
   000.303              00230   MI.JMP  EQU     303Q
                        00231   * Ports for H8-4
   000.340              00232   LP4     EQU     0E0H
   000.340              00233   TX4     EQU     LP4
   000.340              00234   RX4     EQU     LP4
   000.340              00235   DVL4    EQU     LP4
   000.341              00236   DVH4    EQU     LP4+1
   000.341              00237   IER4    EQU     LP4+1
   000.343              00238   LCNTL4  EQU     LP4+3
   000.344              00239   MCNTL4  EQU     LP4+4
   000.345              00240   LSTAT4  EQU     LP4+5
                        00241   *
   000.350              00242   TX5     EQU     350Q
   000.350              00243   RX5     EQU     350Q
   000.355              00244   LSTAT5  EQU     TX5+5
                        00245   *
   042.200              00246           ORG     USERFWA
                        00247   *
   042.200              00248   START   EQU     *
   042.200  021 000 040 00249           LXI     D,BUFSIZ
   042.203  041 232 051 00250           LXI     H,SECBUF
   042.206  315 341 042 00251           CALL    ZEROMEM
                        00252   * DISMOUNT ALL DRIVES
   042.211  041 067 051 00253           LXI     H,DEV1
   042.214  377 203     00254           SCALL   .DMNMS
   042.216  041 074 051 00255           LXI     H,DEV2
   042.221  377 203     00256           SCALL   .DMNMS
   042.223  041 101 051 00257           LXI     H,DEV3
   042.226  377 203     00258           SCALL   .DMNMS
                        00259   *
   042.230  315 236 042 00260           CALL    SINT
                        00261   *
   042.233  303 141 044 00262           JMP     BEGIN










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page    2

                        00263   *
                        00264   * SETUP LPT PORT FOR XXXX,8N2
                        00265   *
   042.236              00266   SINT    EQU     *
   042.236  257         00267           XRA     A
   042.237  323 343     00268           OUT     LCNTL4
   042.241  323 341     00269           OUT     IER4
   042.243  323 344     00270           OUT     MCNTL4
   042.245  075         00271           DCR     A
   042.246  323 343     00272           OUT     LCNTL4
   042.250  076 003     00273           MVI     A,BAUDIV
   042.252  323 340     00274           OUT     DVL4
   042.254  257         00275           XRA     A
   042.255  323 341     00276           OUT     DVH4
   042.257  076 007     00277           MVI     A,07H
   042.261  323 343     00278           OUT     LCNTL4
   042.263  333 345     00279           IN      LSTAT4
   042.265  333 340     00280           IN      RX4
   042.267  311         00281           RET
                        00282   *
                        00283   * SEND A CHAR IN (A) TO THE LP PORT (340Q)
                        00284   *
   042.270  365         00285   CHROUT  PUSH    PSW
   042.271  333 345     00286   CHRO4   IN      LSTAT4
   042.273  346 140     00287           ANI     60H
   042.275  376 140     00288           CPI     60H
   042.277  302 271 042 00289           JNZ     CHRO4
   042.302  361         00290           POP     PSW
   042.303  323 340     00291           OUT     TX4
   042.305  311         00292           RET
                        00293   *
                        00294   * READ A CHAR FROM THE LP PORT (340Q)
                        00295   *
   042.306  333 345     00296   CHRIN   IN      LSTAT4
   042.310  037         00297           RAR
   042.311  322 306 042 00298           JNC     CHRIN
   042.314  333 340     00299           IN      RX4
   042.316  311         00300           RET
                        00301   *
   042.317  333 345     00302   CHRRDY  IN      LSTAT4
   042.321  037         00303           RAR
   042.322  311         00304           RET                     Returns NC = no char, C = char ready
                        00305   * DIRECT OUT TO CONSOLE PORT
   042.323  365         00306   OUT350  PUSH    PSW
   042.324  333 355     00307   OUT35A  IN      LSTAT5
   042.326  346 140     00308           ANI     60H
   042.330  376 140     00309           CPI     60H
   042.332  302 324 042 00310           JNZ     OUT35A
   042.335  361         00311           POP     PSW
   042.336  323 350     00312           OUT     TX5
   042.340  311         00313           RET
                        00314   *
   042.341              00315   ZEROMEM EQU     *
   042.341  257         00316           XRA     A
   042.342  167         00317           MOV     M,A
   042.343  043         00318           INX     H
   042.344  033         00319           DCX     D










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page    3

   042.345  173         00320           MOV     A,E
   042.346  262         00321           ORA     D
   042.347  302 341 042 00322           JNZ     ZEROMEM
   042.352  311         00323           RET
                        00324   * FLIP LATCH TO COMMAND MODE
   042.353              00325   H37CMD  EQU     *
   042.353  076 000     00326           MVI     A,CON.CD
   042.355  323 171     00327           OUT     DK.INT
   042.357  311         00328           RET
                        00329   * FLIP LATCH TO SECTOR/TRACK MODE
   042.360              00330   H37TRK  EQU     *
   042.360  076 001     00331           MVI     A,CON.ST
   042.362  323 171     00332           OUT     DK.INT
   042.364  311         00333           RET
                        00334   *
   042.365              00335   BITS    EQU     *
   042.365  305         00336           PUSH    B
   042.366  365         00337           PUSH    PSW
   042.367  076 200     00338           MVI     A,10000000B
   042.371  004         00339           INR     B
   042.372  007         00340   BITS1   RLC
   042.373  005         00341           DCR     B
   042.374  302 372 042 00342           JNZ     BITS1
   042.377  117         00343           MOV     C,A
   043.000  361         00344           POP     PSW
   043.001  261         00345           ORA     C
   043.002  301         00346           POP     B
   043.003  311         00347           RET
                        00348   * INT4 ROUTINE
   043.004              00349   MYINT   EQU     *
   043.004  333 172     00350           IN      FD.STAT
   043.006  341         00351           POP     H
   043.007  052 067 040 00352           LHLD    BLKICW
   043.012  373         00353           EI
   043.013  351         00354           PCHL
                        00355   *
   043.014              00356   RSTBSY  EQU     *
   043.014  076 320     00357           MVI     A,FDC.FI
   043.016  323 172     00358           OUT     FD.CMD
   043.020  076 001     00359           MVI     A,1
   043.022  315 053 000 00360           CALL    DLY
   043.025  333 172     00361           IN      FD.STAT
   043.027  311         00362           RET
                        00363   * DISK DRIVE UNIT TO WD1797 BITS
   043.030              00364   UNIBITS EQU     *
   043.030  072 061 041 00365           LDA     AIO.UNI
   043.033  306 004     00366           ADI     4
   043.035  107         00367           MOV     B,A
   043.036  257         00368           XRA     A
   043.037  315 365 042 00369           CALL    BITS
   043.042  311         00370           RET
                        00371   * SELECT AIO.UNI
   043.043              00372   SELDRV  EQU     *
   043.043  305         00373           PUSH    B
   043.044  315 353 042 00374           CALL    H37CMD
   043.047  315 062 043 00375           CALL    SETDENS
   043.052  373         00376           EI










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page    4

   043.053  076 226     00377           MVI     A,300/2
   043.055  315 053 000 00378           CALL    DLY
   043.060  301         00379           POP     B
   043.061  311         00380           RET
                        00381   * SET DENSITY FROM (DENS)
   043.062              00382   SETDENS EQU     *
   043.062  315 030 043 00383           CALL    UNIBITS         A=DRIVE BIT
   043.065  366 011     00384           ORI     CON.MO+CON.EI
   043.067  117         00385           MOV     C,A
   043.070  072 112 051 00386           LDA     DENS            CON.MFM OR 0
   043.073  261         00387           ORA     C
   043.074  062 111 051 00388           STA     CONCMD          DS0+CON.MO+CON.EI+CON.MFM
   043.077  323 170     00389           OUT     DK.CON
   043.101  311         00390           RET
                        00391   *
   043.102              00392   SETMFM  EQU     *
   043.102  076 004     00393           MVI     A,CON.MFM
   043.104  062 112 051 00394           STA     DENS
   043.107  303 062 043 00395           JMP     SETDENS
                        00396   *
   043.112              00397   SETFM   EQU     *
   043.112  076 000     00398           MVI     A,0
   043.114  062 112 051 00399           STA     DENS
   043.117  303 062 043 00400           JMP     SETDENS
                        00401   * SWITCH DENSITY FM<->MFM
   043.122              00402   CHGDENS EQU     *
   043.122  072 112 051 00403           LDA     DENS
   043.125  376 004     00404           CPI     CON.MFM
   043.127  312 112 043 00405           JZ      SETFM
   043.132  303 102 043 00406           JMP     SETMFM
                        00407   * DESELECT ALL DRIVES
   043.135              00408   DSLDRV  EQU     *
   043.135  365         00409           PUSH    PSW
   043.136  076 320     00410           MVI     A,FDC.FI
   043.140  323 172     00411           OUT     FD.CMD
   043.142  257         00412           XRA     A
   043.143  323 170     00413           OUT     DK.CON
   043.145  361         00414           POP     PSW
   043.146  311         00415           RET
                        00416   * 40MS DELAY
   043.147              00417   DLY40   EQU     *
   043.147  365         00418           PUSH    PSW
   043.150  305         00419           PUSH    B
   043.151  001 200 014 00420           LXI     B,3200
   043.154  013         00421   DLY40A  DCX     B
   043.155  170         00422           MOV     A,B
   043.156  261         00423           ORA     C
   043.157  302 154 043 00424           JNZ     DLY40A
   043.162  301         00425           POP     B
   043.163  361         00426           POP     PSW
   043.164  311         00427           RET
                        00428   * SET UP INTERRUPT 4 VECTOR
   043.165              00429   SUPINT  EQU     *
   043.165  041 004 043 00430           LXI     H,MYINT
   043.170  042 051 040 00431           SHLD    UIVEC+9+1
   043.173  076 303     00432           MVI     A,MI.JMP
   043.175  062 050 040 00433           STA     UIVEC+9










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page    5

   043.200  311         00434           RET
                        00435   * WAIT HERE UNTIL INTERRUPT JUMPS TO BLKICW
   043.201              00436   WAITINT EQU     *
   043.201  303 201 043 00437           JMP     WAITINT
                        00438   * C=TRACK
   043.204              00439   STPIN   EQU     *
   043.204  315 043 043 00440           CALL    SELDRV
   043.207  041 224 043 00441           LXI     H,STPI2
   043.212  042 067 040 00442           SHLD    BLKICW
   043.215              00443   STPI1   EQU     *
   043.215  076 102     00444           MVI     A,FDC.STI+FDF.S20
   043.217  323 172     00445           OUT     FD.CMD
   043.221  303 201 043 00446           JMP     WAITINT
   043.224              00447   STPI2   EQU     *
   043.224  072 106 051 00448           LDA     CURTRK
   043.227  074         00449           INR     A
   043.230  062 106 051 00450           STA     CURTRK
   043.233  271         00451           CMP     C
   043.234  302 215 043 00452           JNZ     STPI1
   043.237  315 147 043 00453           CALL    DLY40
   043.242  311         00454           RET
                        00455   * C=TRACK
   043.243              00456   STPOUT  EQU     *
   043.243  315 043 043 00457           CALL    SELDRV
   043.246  072 106 051 00458           LDA     CURTRK
   043.251  267         00459           ORA     A
   043.252  312 311 043 00460           JZ      SEEK0
   043.255  041 272 043 00461           LXI     H,STPO2
   043.260  042 067 040 00462           SHLD    BLKICW
   043.263              00463   STPO1   EQU     *
   043.263  076 142     00464           MVI     A,FDC.STO+FDF.S20
   043.265  323 172     00465           OUT     FD.CMD
   043.267  303 201 043 00466           JMP     WAITINT
   043.272              00467   STPO2   EQU     *
   043.272  072 106 051 00468           LDA     CURTRK
   043.275  075         00469           DCR     A
   043.276  062 106 051 00470           STA     CURTRK
   043.301  271         00471           CMP     C
   043.302  302 263 043 00472           JNZ     STPO1
   043.305  315 147 043 00473           CALL    DLY40
   043.310  311         00474           RET
                        00475   * SEEK TO TRACK 0
   043.311              00476   SEEK0   EQU     *
   043.311  315 043 043 00477           CALL    SELDRV
   043.314  257         00478           XRA     A
   043.315  062 106 051 00479           STA     CURTRK
   043.320  041 335 043 00480           LXI     H,SEEKD
   043.323  042 067 040 00481           SHLD    BLKICW
   043.326  076 002     00482           MVI     A,FDC.RST+FDF.S20
   043.330  323 172     00483           OUT     FD.CMD
   043.332  303 201 043 00484           JMP     WAITINT
   043.335              00485   SEEKD   EQU     *
   043.335  036 012     00486           MVI     E,10            STEP IN 10 TIMES
   043.337  041 354 043 00487           LXI     H,SEEKD2
   043.342  042 067 040 00488           SHLD    BLKICW
   043.345              00489   SEEKD1  EQU     *
   043.345  076 102     00490           MVI     A,FDC.STI+FDF.S20










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page    6

   043.347  323 172     00491           OUT     FD.CMD
   043.351  303 201 043 00492           JMP     WAITINT
   043.354              00493   SEEKD2  EQU     *
   043.354  035         00494           DCR     E
   043.355  302 345 043 00495           JNZ     SEEKD1
                        00496   * DOUBLE RESTORE
   043.360  041 375 043 00497           LXI     H,SEEKD3
   043.363  042 067 040 00498           SHLD    BLKICW
   043.366  076 002     00499           MVI     A,FDC.RST+FDF.S20
   043.370  323 172     00500           OUT     FD.CMD
   043.372  303 201 043 00501           JMP     WAITINT
   043.375              00502   SEEKD3  EQU     *
   043.375  315 147 043 00503           CALL    DLY40           HEAD SETTLE TIME
   044.000  346 004     00504           ANI     FDS.TK0
   044.002  300         00505           RNZ
   044.003  067         00506           STC
   044.004  311         00507           RET
                        00508   * C=TRK (STEP IN OR OUT TO REACH TARGET)
   044.005              00509   SEEKTO  EQU     *
   044.005  315 360 042 00510           CALL    H37TRK
   044.010  171         00511           MOV     A,C
   044.011  323 173     00512           OUT     FD.TRK          SET TRACK REGISTER
   044.013  072 106 051 00513           LDA     CURTRK
   044.016  221         00514           SUB     C
   044.017  310         00515           RZ                      ALREADY AT TRK C
   044.020  332 204 043 00516           JC      STPIN
   044.023  303 243 043 00517           JMP     STPOUT
                        00518   * DE=BUFFER - READ TRACK INTO BUFFER
   044.026              00519   READLP  EQU     *
   044.026  001 000 000 00520           LXI     B,0             TOTAL BYTES READ
   044.031  041 074 044 00521           LXI     H,READL2        RETURN ADDRESS
   044.034  042 067 040 00522           SHLD    BLKICW
   044.037  315 353 042 00523           CALL    H37CMD
   044.042  072 111 051 00524           LDA     CONCMD
   044.045  366 002     00525           ORI     CON.DRQ
   044.047  323 170     00526           OUT     DK.CON
                        00527   * RDS=READ SECTOR
                        00528   * DLF=15MS DELAY
                        00529   * MRF=READ TO END OF TRACK
                        00530   * SLF=SECTOR LEN SHIFT (128,256,512,1024)
                        00531   * SS1=SIDE 1 FLAG
   044.051  257         00532           XRA     A
   044.052  072 110 051 00533           LDA     SIDE            0=SIDE 1,1=SIDE 2
   044.055  027         00534           RAL                     IF A=1 THEN RAL=FDF.SS1
   044.056  366 234     00535           ORI     FDC.RDS+FDF.DLF+FDF.MRF+FDF.SLF
   044.060  323 172     00536           OUT     FD.CMD
   044.062  041 065 044 00537           LXI     H,READL1
   044.065              00538   READL1  EQU     *               LOOP UNTIL IRQ4
   044.065  166         00539           HLT                     WAIT FOR DRQ
   044.066  333 173     00540           IN      FD.DAT
   044.070  022         00541           STAX    D
   044.071  023         00542           INX     D
   044.072  003         00543           INX     B
   044.073  351         00544           PCHL                    LOOP BACK TO READL1
   044.074              00545   READL2  EQU     *
   044.074  076 010     00546           MVI     A,CON.MO
   044.076  323 170     00547           OUT     DK.CON










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page    7

   044.100  151         00548           MOV     L,C
   044.101  140         00549           MOV     H,B
   044.102  042 114 051 00550           SHLD    RDCNT
   044.105  315 360 042 00551           CALL    H37TRK
   044.110  333 172     00552           IN      FD.SEC
   044.112  075         00553           DCR     A
   044.113  062 113 051 00554           STA     SPERT
   044.116  267         00555           ORA     A               SECTORS PER TRACK == 0?
   044.117  300         00556           RNZ                     NO ERRORS
   044.120  067         00557           STC                     ERROR, SET CARRY FLAG
   044.121  311         00558           RET
                        00559   * B=SEC (1-255),C=TRK (0-255)
   044.122              00560   READS   EQU     *
   044.122  315 360 042 00561           CALL    H37TRK
   044.125  170         00562           MOV     A,B
   044.126  323 172     00563           OUT     FD.SEC          SET SECTOR REGISTER
   044.130  315 005 044 00564           CALL    SEEKTO
   044.133  021 232 051 00565           LXI     D,SECBUF
   044.136  303 026 044 00566           JMP     READLP
                        00567   *
                        00568   * IMAGER COMMANDS
                        00569   * R = READ IMAGE SEND TO HOST
                        00570   * W = WRITE IMAGE FROM HOST
                        00571   * 0 = DK0
                        00572   * 1 = DK1
                        00573   * 4 = 1S40T
                        00574   * 5 = 2S40T
                        00575   * 6 = 1S80T
                        00576   * 7 = 2S80T
                        00577   * A = SIDE 1
                        00578   * B = SIDE 2
                        00579   * E = EXAMINE TRACK
                        00580   * Q = QUERY DISK TYPE
                        00581   * T = QUERY TRACK HEADER
                        00582   *
   044.141              00583   BEGIN   EQU     *
   044.141  315 136 031 00584           CALL    $TYPTX
   044.144  012 110 063 00585           DB      0AH,'H37IMGR 2021.09.30 BY LES BIRD',0AH
   044.204  123 117 106 00586           DB      'SOFT SECTOR DISK IMAGING PROGRAM',0AH
   044.245  104 122 111 00587           DB      'DRIVE CONFIGURATION SHOULD BE AS FOLLOWS:',0AH
   044.317  104 113 060 00588           DB      'DK0: DS 40 TRACK',0AH
   044.340  104 113 061 00589           DB      'DK1: DS 80 TRACK',8AH
   044.361  315 353 042 00590           CALL    H37CMD
   044.364  315 014 043 00591           CALL    RSTBSY
   044.367  315 165 043 00592           CALL    SUPINT
   044.372  257         00593           XRA     A               SET DRIVE UNIT TO 0
   044.373  062 061 041 00594           STA     AIO.UNI
   044.376  074         00595           INR     A
   044.377  062 117 051 00596           STA     NUMSID          SINGLE SIDE IS DEFAULT
   045.002  076 050     00597           MVI     A,40
   045.004  062 116 051 00598           STA     NUMTRK          40 TRACK IS DEFAULT
   045.007  315 043 043 00599           CALL    SELDRV
   045.012  315 311 043 00600           CALL    SEEK0           SEEK TRACK 0
   045.015              00601   BEGLP   EQU     *
   045.015  315 136 031 00602           CALL    $TYPTX
   045.020  127 101 111 00603           DB      'WAITING FOR COMMAND:',80H
   045.045  315 135 043 00604           CALL    DSLDRV










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page    8

   045.050              00605   BEGLP1  EQU     *
   045.050  315 306 042 00606           CALL    CHRIN           WAIT FOR COMMAND FROM LP PORT
   045.053  376 122     00607           CPI     'R'             READ DISK IMAGE
   045.055  312 171 045 00608           JZ      CMDRDI
   045.060  376 127     00609           CPI     'W'
   045.062  312 027 046 00610           JZ      CMDWDI
   045.065  376 060     00611           CPI     '0'
   045.067  312 030 046 00612           JZ      SETDK0
   045.072  376 061     00613           CPI     '1'
   045.074  312 062 046 00614           JZ      SETDK1
   045.077  376 063     00615           CPI     '3'             IDENTIFY AS H37IMGR
   045.101  312 115 046 00616           JZ      ISH37
   045.104  376 064     00617           CPI     '4'
   045.106  312 163 046 00618           JZ      SET1S4
   045.111  376 065     00619           CPI     '5'
   045.113  312 230 046 00620           JZ      SET2S4
   045.116  376 066     00621           CPI     '6'
   045.120  312 275 046 00622           JZ      SET1S8
   045.123  376 067     00623           CPI     '7'
   045.125  312 343 046 00624           JZ      SET2S8
   045.130  376 121     00625           CPI     'Q'
   045.132  312 011 047 00626           JZ      QUERY
   045.135  376 124     00627           CPI     'T'
   045.137  312 011 050 00628           JZ      GETTRK
   045.142  376 105     00629           CPI     'E'
   045.144  312 163 050 00630           JZ      EXMTRK
   045.147  376 101     00631           CPI     'A'
   045.151  312 206 050 00632           JZ      SETSID1
   045.154  376 102     00633           CPI     'B'
   045.156  312 236 050 00634           JZ      SETSID2
   045.161  076 077     00635           MVI     A,'?'
   045.163  315 270 042 00636           CALL    CHROUT
   045.166  303 050 045 00637           JMP     BEGLP1
                        00638   * CMD READ DISK IMAGE
   045.171              00639   CMDRDI  EQU     *
   045.171  315 136 031 00640           CALL    $TYPTX
   045.174  122 105 101 00641           DB      'READ DISK IMAGE',8AH
   045.214  315 043 043 00642           CALL    SELDRV
   045.217  257         00643           XRA     A
   045.220  062 110 051 00644           STA     SIDE            INITIALIZE SIDE
   045.223  001 000 001 00645           LXI     B,0100H         START SECTOR 1, TRACK 0
   045.226              00646   CMDRD1  EQU     *
   045.226  315 306 042 00647           CALL    CHRIN           WAIT FOR REQUEST
   045.231  376 122     00648           CPI     'R'
   045.233  302 015 045 00649           JNZ     BEGLP           NOT 'R' SO PROBABLY ABORT
   045.236  305         00650           PUSH    B
   045.237  076 122     00651           MVI     A,'R'
   045.241  315 323 042 00652           CALL    OUT350
                        00653   *
   045.244  315 122 044 00654           CALL    READS           READ TRACK
                        00655   *
   045.247  076 010     00656           MVI     A,08H
   045.251  315 323 042 00657           CALL    OUT350
   045.254  076 123     00658           MVI     A,'S'
   045.256  315 323 042 00659           CALL    OUT350          SHOW SENDING BUFFER
                        00660   *
   045.261  315 355 045 00661           CALL    SENDT           SEND TRACK BUFFER










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page    9

                        00662   *
   045.264  076 010     00663           MVI     A,08H
   045.266  315 323 042 00664           CALL    OUT350
   045.271  076 052     00665           MVI     A,'*'
   045.273  315 323 042 00666           CALL    OUT350          SHOW TRACK SENT
   045.276  301         00667           POP     B               GET SEC,TRK
   045.277  072 117 051 00668           LDA     NUMSID          1 OR 2
   045.302  075         00669           DCR     A
   045.303  312 324 045 00670           JZ      CMDRD2          SINGLE SIDED
   045.306  072 110 051 00671           LDA     SIDE            0 OR 1
   045.311  267         00672           ORA     A
   045.312  302 324 045 00673           JNZ     CMDRD2          FINISHED SIDE 2
   045.315  074         00674           INR     A
   045.316  062 110 051 00675           STA     SIDE
   045.321  303 226 045 00676           JMP     CMDRD1          READ SIDE 2
   045.324              00677   CMDRD2  EQU     *
   045.324  257         00678           XRA     A
   045.325  062 110 051 00679           STA     SIDE            SET SIDE 1
   045.330  014         00680           INR     C
   045.331  072 116 051 00681           LDA     NUMTRK
   045.334  271         00682           CMP     C
   045.335  302 226 045 00683           JNZ     CMDRD1
   045.340  076 015     00684           MVI     A,0DH
   045.342  315 323 042 00685           CALL    OUT350
   045.345  076 012     00686           MVI     A,0AH
   045.347  315 323 042 00687           CALL    OUT350
   045.352  303 015 045 00688           JMP     BEGLP
                        00689   * SEND TRACK DATA TO 340Q
   045.355              00690   SENDT   EQU     *
   045.355  052 114 051 00691           LHLD    RDCNT
   045.360  175         00692           MOV     A,L
   045.361  315 270 042 00693           CALL    CHROUT
   045.364  174         00694           MOV     A,H
   045.365  315 270 042 00695           CALL    CHROUT
   045.370  072 113 051 00696           LDA     SPERT
   045.373  315 270 042 00697           CALL    CHROUT
   045.376  175         00698           MOV     A,L
   045.377  264         00699           ORA     H
   046.000  312 021 046 00700           JZ      SENDT2
   046.003  021 232 051 00701           LXI     D,SECBUF
   046.006              00702   SENDT1  EQU     *
   046.006  032         00703           LDAX    D
   046.007  315 270 042 00704           CALL    CHROUT
   046.012  023         00705           INX     D
   046.013  053         00706           DCX     H
   046.014  175         00707           MOV     A,L
   046.015  264         00708           ORA     H
   046.016  302 006 046 00709           JNZ     SENDT1
   046.021              00710   SENDT2  EQU     *
   046.021  076 122     00711           MVI     A,'R'
   046.023  315 270 042 00712           CALL    CHROUT          HANDSHAKE
   046.026  311         00713           RET
                        00714   * COMMAND WRITE DISK IMAGE
   046.027              00715   CMDWDI  EQU     *
   046.027  311         00716           RET
                        00717   * COMMAND SET DRIVE 0
   046.030              00718   SETDK0  EQU     *










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page   10

   046.030  365         00719           PUSH    PSW
   046.031  315 136 031 00720           CALL    $TYPTX
   046.034  123 105 124 00721           DB      'SET DK0',8AH
   046.044  257         00722           XRA     A
   046.045  062 061 041 00723           STA     AIO.UNI
   046.050  315 311 043 00724           CALL    SEEK0
   046.053  361         00725           POP     PSW
   046.054  315 270 042 00726           CALL    CHROUT          HANDSHAKE
   046.057  303 015 045 00727           JMP     BEGLP
                        00728   * COMMAND SET DRIVE 1
   046.062              00729   SETDK1  EQU     *
   046.062  365         00730           PUSH    PSW
   046.063  315 136 031 00731           CALL    $TYPTX
   046.066  123 105 124 00732           DB      'SET DK1',8AH
   046.076  076 001     00733           MVI     A,1
   046.100  062 061 041 00734           STA     AIO.UNI
   046.103  315 311 043 00735           CALL    SEEK0
   046.106  361         00736           POP     PSW
   046.107  315 270 042 00737           CALL    CHROUT
   046.112  303 015 045 00738           JMP     BEGLP
                        00739   * H37 IMAGER IDENTIFIER
   046.115              00740   ISH37   EQU     *
   046.115  315 270 042 00741           CALL    CHROUT
   046.120  315 136 031 00742           CALL    $TYPTX
   046.123  111 104 105 00743           DB      'IDENTIFY AS H37IMGR',8AH
   046.147  303 015 045 00744           JMP     BEGLP
                        00745   * SET DRIVE PARAMETERS (SIDES,TRACKS)
   046.152              00746   SETPAR  EQU     *
   046.152  170         00747           MOV     A,B
   046.153  062 117 051 00748           STA     NUMSID
   046.156  171         00749           MOV     A,C
   046.157  062 116 051 00750           STA     NUMTRK
   046.162  311         00751           RET
                        00752   * COMMAND SET SS 40 TRACK
   046.163              00753   SET1S4  EQU     *
   046.163  365         00754           PUSH    PSW
   046.164  315 136 031 00755           CALL    $TYPTX
   046.167  123 105 124 00756           DB      'SET SS 40 TRACK',8AH
   046.207  001 050 001 00757           LXI     B,0128H
   046.212  315 152 046 00758           CALL    SETPAR
   046.215  257         00759           XRA     A
   046.216  062 061 041 00760           STA     AIO.UNI
   046.221  361         00761           POP     PSW
   046.222  315 270 042 00762           CALL    CHROUT
   046.225  303 015 045 00763           JMP     BEGLP
                        00764   * COMMAND SET DS 40 TRACK
   046.230              00765   SET2S4  EQU     *
   046.230  365         00766           PUSH    PSW
   046.231  315 136 031 00767           CALL    $TYPTX
   046.234  123 105 124 00768           DB      'SET DS 40 TRACK',8AH
   046.254  001 050 002 00769           LXI     B,0228H
   046.257  315 152 046 00770           CALL    SETPAR
   046.262  257         00771           XRA     A
   046.263  062 061 041 00772           STA     AIO.UNI
   046.266  361         00773           POP     PSW
   046.267  315 270 042 00774           CALL    CHROUT
   046.272  303 015 045 00775           JMP     BEGLP










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page   11

                        00776   * COMMAND SET SS 80 TRACK
   046.275              00777   SET1S8  EQU     *
   046.275  365         00778           PUSH    PSW
   046.276  315 136 031 00779           CALL    $TYPTX
   046.301  123 105 124 00780           DB      'SET SS 80 TRACK',8AH
   046.321  001 120 001 00781           LXI     B,0150H
   046.324  315 152 046 00782           CALL    SETPAR
   046.327  076 001     00783           MVI     A,1
   046.331  062 061 041 00784           STA     AIO.UNI
   046.334  361         00785           POP     PSW
   046.335  315 270 042 00786           CALL    CHROUT
   046.340  303 015 045 00787           JMP     BEGLP
                        00788   * COMMAND SET DS 80 TRACK
   046.343              00789   SET2S8  EQU     *
   046.343  365         00790           PUSH    PSW
   046.344  315 136 031 00791           CALL    $TYPTX
   046.347  123 105 124 00792           DB      'SET DS 80 TRACK',8AH
   046.367  001 120 002 00793           LXI     B,0250H
   046.372  315 152 046 00794           CALL    SETPAR
   046.375  076 001     00795           MVI     A,1
   046.377  062 061 041 00796           STA     AIO.UNI
   047.002  361         00797           POP     PSW
   047.003  315 270 042 00798           CALL    CHROUT
   047.006  303 015 045 00799           JMP     BEGLP
                        00800   * COMMAND QUERY DISK TYPE
   047.011              00801   QUERY   EQU     *
   047.011  315 270 042 00802           CALL    CHROUT
   047.014  315 136 031 00803           CALL    $TYPTX
   047.017  121 125 105 00804           DB      'QUERY DISK TYPE',8AH
   047.037  001 000 000 00805           LXI     B,0             SEC,TRK=0
   047.042  315 155 047 00806           CALL    QUERY1
   047.045  315 053 047 00807           CALL    QUERYR
   047.050  303 015 045 00808           JMP     BEGLP
   047.053              00809   QUERYR  EQU     *
   047.053  072 113 051 00810           LDA     SPERT           SECTORS PER TRACK
   047.056  315 270 042 00811           CALL    CHROUT
                        00812   * READ ADDRESS RESULTS
   047.061  072 120 051 00813           LDA     QTRK            TRACK
   047.064  315 270 042 00814           CALL    CHROUT
   047.067  072 121 051 00815           LDA     QSID            SIDE
   047.072  315 270 042 00816           CALL    CHROUT
   047.075  072 122 051 00817           LDA     QSEC            SECTOR
   047.100  315 270 042 00818           CALL    CHROUT
   047.103  072 123 051 00819           LDA     QSECL           SECTOR LENGTH
   047.106  315 270 042 00820           CALL    CHROUT
   047.111  072 124 051 00821           LDA     QCRC1           CRC 1
   047.114  315 270 042 00822           CALL    CHROUT
   047.117  072 125 051 00823           LDA     QCRC2           CRC 2
   047.122  315 270 042 00824           CALL    CHROUT
                        00825   * DISK PARAMETERS
   047.125  072 117 051 00826           LDA     NUMSID          NUM SIDES
   047.130  315 270 042 00827           CALL    CHROUT
   047.133  052 114 051 00828           LHLD    RDCNT
   047.136  175         00829           MOV     A,L             RDCNT LOW BYTE
   047.137  315 270 042 00830           CALL    CHROUT
   047.142  174         00831           MOV     A,H             RDCNT HIGH BYTE
   047.143  315 270 042 00832           CALL    CHROUT










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page   12

   047.146  072 112 051 00833           LDA     DENS            DENSITY CON.MFM OR 0
   047.151  315 270 042 00834           CALL    CHROUT
   047.154  311         00835           RET
                        00836   * READ/DETERMINE DISK TYPE
   047.155              00837   QUERY1  EQU     *
   047.155  257         00838           XRA     A
   047.156  062 113 051 00839           STA     SPERT
   047.161  076 004     00840           MVI     A,CON.MFM       TEST MFM FIRST
   047.163  062 112 051 00841           STA     DENS
   047.166  315 043 043 00842           CALL    SELDRV
   047.171  021 000 040 00843           LXI     D,BUFSIZ
   047.174  041 232 051 00844           LXI     H,SECBUF
   047.177  315 341 042 00845           CALL    ZEROMEM
   047.202              00846   QUERYL  EQU     *
   047.202  076 002     00847           MVI     A,2
   047.204  062 117 051 00848           STA     NUMSID          DOUBLE SIDED DEFAULT
   047.207  075         00849           DCR     A
   047.210  062 110 051 00850           STA     SIDE
   047.213  107         00851           MOV     B,A             SECTOR 1, C=TRK
   047.214  315 122 044 00852           CALL    READS           TEST READ SIDE 2
   047.217  365         00853           PUSH    PSW
   047.220  257         00854           XRA     A
   047.221  062 110 051 00855           STA     SIDE
   047.224  361         00856           POP     PSW
   047.225  322 325 047 00857           JNC     QUERYS          GOOD DOUBLE SIDE READ
   047.230  076 001     00858           MVI     A,1
   047.232  062 117 051 00859           STA     NUMSID          SINGLE SIDED DISK
   047.235  107         00860           MOV     B,A
   047.236  072 106 051 00861           LDA     CURTRK
   047.241  117         00862           MOV     C,A
   047.242  315 122 044 00863           CALL    READS           READ A TRACK FILL SPERT+RDCNT
   047.245  322 325 047 00864           JNC     QUERYS          GOOD SINGLE SIDE READ
   047.250  072 112 051 00865           LDA     DENS
   047.253  376 004     00866           CPI     CON.MFM
   047.255  302 372 047 00867           JNZ     QUERY3          FAILED MFM AND FM
   047.260  315 136 031 00868           CALL    $TYPTX
   047.263  103 110 105 00869           DB      'CHECKING SINGLE DENSITY',8AH
   047.313  315 122 043 00870           CALL    CHGDENS         MIGHT BE FM
   047.316  072 106 051 00871           LDA     CURTRK
   047.321  117         00872           MOV     C,A
   047.322  303 202 047 00873           JMP     QUERYL
                        00874   * JUST READ THE HEADER
   047.325              00875   QUERYS  EQU     *
   047.325  315 353 042 00876           CALL    H37CMD
   047.330  041 372 047 00877           LXI     H,QUERY3
   047.333  042 067 040 00878           SHLD    BLKICW
   047.336  072 111 051 00879           LDA     CONCMD
   047.341  366 002     00880           ORI     CON.DRQ
   047.343  323 170     00881           OUT     DK.CON
   047.345  001 000 000 00882           LXI     B,0
   047.350  021 120 051 00883           LXI     D,QBUF
   047.353  041 363 047 00884           LXI     H,QUERY2
   047.356  257         00885           XRA     A
   047.357  366 304     00886           ORI     FDC.RDA+FDF.DLF
   047.361  323 172     00887           OUT     FD.CMD
   047.363              00888   QUERY2  EQU     *               LOOP UNTIL IRQ4
   047.363  166         00889           HLT                     WAIT FOR DRQ










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page   13

   047.364  333 173     00890           IN      FD.DAT
   047.366  022         00891           STAX    D
   047.367  023         00892           INX     D
   047.370  003         00893           INX     B
   047.371  351         00894           PCHL
   047.372              00895   QUERY3  EQU     *
   047.372  076 320     00896           MVI     A,FDC.FI
   047.374  323 172     00897           OUT     FD.CMD
   047.376  333 173     00898           IN      FD.DAT
   050.000  076 010     00899           MVI     A,CON.MO
   050.002  323 170     00900           OUT     DK.CON
   050.004  171         00901           MOV     A,C
   050.005  260         00902           ORA     B
   050.006  300         00903           RNZ
   050.007  067         00904           STC
   050.010  311         00905           RET
                        00906   * GET TRACK HEADER
   050.011              00907   GETTRK  EQU     *
   050.011  315 270 042 00908           CALL    CHROUT          HANDSHAKE
   050.014  315 306 042 00909           CALL    CHRIN           GET TRACK TO CHECK
   050.017  117         00910           MOV     C,A             STORE TRACK
   050.020  305         00911           PUSH    B
   050.021  315 136 031 00912           CALL    $TYPTX
   050.024  121 125 105 00913           DB      'QUERY TRACK',8AH
   050.040  301         00914           POP     B
   050.041  315 052 050 00915           CALL    GETTR0
   050.044  315 053 047 00916           CALL    QUERYR
   050.047  303 015 045 00917           JMP     BEGLP
   050.052              00918   GETTR0  EQU     *
   050.052  315 102 043 00919           CALL    SETMFM
   050.055              00920   GETTR1  EQU     *
   050.055  315 325 047 00921           CALL    QUERYS
   050.060  322 162 050 00922           JNC     GETTR3
   050.063  072 112 051 00923           LDA     DENS
   050.066  267         00924           ORA     A
   050.067  312 132 050 00925           JZ      GETTR2
   050.072  315 136 031 00926           CALL    $TYPTX
   050.075  124 122 131 00927           DB      'TRY SINGLE DENSITY',8AH
   050.120  315 112 043 00928           CALL    SETFM
   050.123  072 106 051 00929           LDA     CURTRK
   050.126  117         00930           MOV     C,A
   050.127  303 055 050 00931           JMP     GETTR1
   050.132              00932   GETTR2  EQU     *
   050.132  315 136 031 00933           CALL    $TYPTX
   050.135  104 111 123 00934           DB      'DISK NOT RECOGNIZED',8AH
   050.161  067         00935           STC
   050.162              00936   GETTR3  EQU     *
   050.162  311         00937           RET
                        00938   *
   050.163              00939   EXMTRK  EQU     *
   050.163  315 270 042 00940           CALL    CHROUT          HANDSHAKE
   050.166  315 306 042 00941           CALL    CHRIN
   050.171  117         00942           MOV     C,A             TRACK TO READ
   050.172  315 155 047 00943           CALL    QUERY1
   050.175  315 355 045 00944           CALL    SENDT
   050.200  315 053 047 00945           CALL    QUERYR
   050.203  303 015 045 00946           JMP     BEGLP










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page   14

                        00947   *
   050.206              00948   SETSID1 EQU     *
   050.206  315 270 042 00949           CALL    CHROUT
   050.211  315 136 031 00950           CALL    $TYPTX
   050.214  123 105 124 00951           DB      'SET SIDE 1',8AH
   050.227  257         00952           XRA     A
   050.230  062 110 051 00953           STA     SIDE
   050.233  303 015 045 00954           JMP     BEGLP
                        00955   *
   050.236              00956   SETSID2 EQU     *
   050.236  315 270 042 00957           CALL    CHROUT
   050.241  315 136 031 00958           CALL    $TYPTX
   050.244  123 105 124 00959           DB      'SET SIDE 2',8AH
   050.257  076 001     00960           MVI     A,1
   050.261  062 110 051 00961           STA     SIDE
   050.264  303 015 045 00962           JMP     BEGLP
                        00963   *
   050.267              00964   FMTTRK  EQU     *
   050.267  072 112 051 00965           LDA     DENS
   050.272  267         00966           ORA     A
   050.273  302 302 050 00967           JNZ     FMTDD
                        00968   * SINGLE DENSITY FORMAT
   050.276              00969   FMTSD   EQU     *
   050.276  021 172 051 00970           LXI     D,SDTT
   050.301  311         00971           RET
                        00972   * DOUBLE DENSITY FORMAT
   050.302              00973   FMTDD   EQU     *
   050.302  076 020     00974           MVI     A,16
   050.304  062 113 051 00975           STA     SPERT
   050.307  076 001     00976           MVI     A,1
   050.311  062 142 051 00977           STA     DDSEC           START SECTOR 1
   050.314  072 106 051 00978           LDA     CURTRK
   050.317  062 136 051 00979           STA     DDTRK
   050.322  072 110 051 00980           LDA     SIDE
   050.325  062 140 051 00981           STA     DDSID
   050.330  021 232 051 00982           LXI     D,SECBUF
   050.333  041 126 051 00983           LXI     H,DDTT
   050.336              00984   FMTDD1  EQU     *
   050.336  176         00985           MOV     A,M
   050.337  043         00986           INX     H
   050.340  116         00987           MOV     C,M
   050.341  043         00988           INX     H
   050.342  261         00989           ORA     C
   050.343  312 354 050 00990           JZ      FMTDD2          END OF SECTOR DATA
   050.346  315 060 051 00991           CALL    WDAT
   050.351  303 336 050 00992           JMP     FMTDD1
   050.354              00993   FMTDD2  EQU     *
   050.354  072 113 051 00994           LDA     SPERT
   050.357  074         00995           INR     A
   050.360  117         00996           MOV     C,A
   050.361  072 142 051 00997           LDA     DDSEC
   050.364  074         00998           INR     A
   050.365  062 142 051 00999           STA     DDSEC
   050.370  271         01000           CMP     C
   050.371  302 336 050 01001           JNZ     FMTDD1
                        01002   * WRITE THE TRACK
   050.374              01003   WRTTRK  EQU     *










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page   15

   050.374  072 111 051 01004           LDA     CONCMD
   050.377  366 002     01005           ORI     CON.DRQ
   051.001  323 170     01006           OUT     DK.CON
   051.003  076 364     01007           MVI     A,FDC.WTT+FDF.DLF
   051.005  157         01008           MOV     L,A
   051.006  072 110 051 01009           LDA     SIDE
   051.011  267         01010           ORA     A
   051.012  312 020 051 01011           JZ      WRTTR1
   051.015  076 002     01012           MVI     A,FDF.SS1
   051.017  265         01013           ORA     L
   051.020              01014   WRTTR1  EQU     *
   051.020  041 044 051 01015           LXI     H,WRTTR3
   051.023  042 067 040 01016           SHLD    BLKICW
   051.026  041 036 051 01017           LXI     H,WRTTR2
   051.031  021 232 051 01018           LXI     D,SECBUF
   051.034  323 172     01019           OUT     FD.CMD
   051.036              01020   WRTTR2  EQU     *
   051.036  166         01021           HLT
   051.037  032         01022           LDAX    D
   051.040  323 173     01023           OUT     FD.DAT
   051.042  023         01024           INX     D
   051.043  351         01025           PCHL
   051.044              01026   WRTTR3  EQU     *
   051.044  076 226     01027           MVI     A,150           WRITE GATE DELAY
   051.046  075         01028   WRTTR4  DCR     A
   051.047  302 046 051 01029           JNZ     WRTTR4
   051.052  072 111 051 01030           LDA     CONCMD
   051.055  323 170     01031           OUT     DK.CON
   051.057  311         01032           RET
                        01033   *
   051.060  022         01034   WDAT    STAX    D
   051.061  023         01035           INX     D
   051.062  015         01036           DCR     C
   051.063  302 060 051 01037           JNZ     WDAT
   051.066  311         01038           RET
                        01039   *
   051.067  123 131 060 01040   DEV1    DB      'SY0:',0
   051.074  123 131 061 01041   DEV2    DB      'SY1:',0
   051.101  123 131 062 01042   DEV3    DB      'SY2:',0
                        01043   *
   051.106  000         01044   CURTRK  DB      0               0-79
   051.107  000         01045   CURSEC  DB      0               1-16
   051.110  000         01046   SIDE    DB      0               0 OR 1
   051.111  000         01047   CONCMD  DB      0               LAST COMMAND SENT TO DK.CON
   051.112  004         01048   DENS    DB      CON.MFM
                        01049   *
   051.113  000         01050   SPERT   DB      0               SECTORS PER TRACK
   051.114  000 000     01051   RDCNT   DW      0               BYTES READ
   051.116  000         01052   NUMTRK  DB      0               NUM TRACKS (40 OR 80)
   051.117  000         01053   NUMSID  DB      0               NUM SIDES (1 OR 2)
                        01054   *
   051.120              01055   QBUF    EQU     *
   051.120  000         01056   QTRK    DB      0
   051.121  000         01057   QSID    DB      0
   051.122  000         01058   QSEC    DB      0
   051.123  000         01059   QSECL   DB      0
   051.124  000         01060   QCRC1   DB      0










                                                        HEATH ASM #104.06.00
                                                        01-Jan-77  Page   16

   051.125  000         01061   QCRC2   DB      0
                        01062   *
   051.126  116 050     01063   DDTT    DB      04EH,40
   051.130  000 014     01064   DDTTA   DB      0,12
   051.132  365 003     01065           DB      0F5H,3
   051.134  376 001     01066           DB      0FEH,1
   051.136  000 001     01067   DDTRK   DB      0,1
   051.140  000 001     01068   DDSID   DB      0,1
   051.142  000 001     01069   DDSEC   DB      0,1
   051.144  001 001     01070           DB      1,1
   051.146  367 001     01071           DB      0F7H,1
   051.150  116 026     01072           DB      04EH,22
   051.152  000 014     01073           DB      0,12
   051.154  365 003     01074           DB      0F5H,3
   051.156  373 001     01075           DB      0FBH,1
   051.160  345 200     01076   DDDP1   DB      0E5H,128
   051.162  345 200     01077   DDDP2   DB      0E5H,128
   051.164  367 001     01078           DB      0F7H,1
   051.166  116 053     01079           DB      04EH,43
   051.170  000 000     01080           DB      0,0
                        01081
   051.172  377 040     01082   SDTT    DB      0FFH,32
   051.174  000 006     01083   SDTTA   DB      0,6
   051.176  376 001     01084           DB      0FEH,1
   051.200  000 001     01085   SDTRK   DB      0,1
   051.202  000 001     01086   SDSID   DB      0,1
   051.204  000 001     01087   SDSEC   DB      0,1
   051.206  001 001     01088           DB      1,1
   051.210  367 001     01089           DB      0F7H,1
   051.212  377 013     01090           DB      0FFH,11
   051.214  000 006     01091           DB      0,6
   051.216  373 001     01092           DB      0FBH,1
   051.220  345 200     01093   SDDP1   DB      0E5H,128
   051.222  345 200     01094   SDDP2   DB      0E5H,128
   051.224  367 001     01095           DB      0F7H,1
   051.226  377 020     01096           DB      0FFH,16
   051.230  000 000     01097           DB      0,0
                        01098   *
                        01099   * HEATH 5.25
                        01100   * FM =10 SECTORS, 256 BYTES (2560 BYTES PER TRACK)
                        01101   * MFM=16 SECTORS, 256 BYTES (4096 BYTES PER TRACK)
                        01102   * PC 5.25
                        01103   * MFM= 9 SECTORS, 512 BYTES (4608 BYTES PER TRACK)
                        01104   *
   051.232              01105   SECBUF  DS      BUFSIZ          MAX FULL TRACK
                        01106   *
   111.232  000         01107           END     START


01107 Statements Assembled
37883 Bytes Free
 No Errors Detected










>*
* H37IMGR
*
* 2021.09.30 LES BIRD
* ALSO WORKS FOR PC/Z100 5.25 DISKS (WD179X)
*
        XTEXT   HOSEQU
        XTEXT   HOSDEF
        XTEXT   H37DEF
        XTEXT   HROM
*
BUFSIZ  EQU     8192            DISK TRACK BUFFER SIZE
BAUD96  EQU     0CH             9,600 BAUD
BAUD19  EQU     06H             19,200 BAUD
BAUD38  EQU     03H             38,400 BAUD
BAUD56  EQU     02H             56,000 BAUD
*
BAUDIV  EQU     03H             19200 BAUD IS DEFAULT
*
DLY     EQU     53A
UIVEC   EQU     40037A          USER INTERRUPT VECTOR
BLKICW  EQU     40067A          INTERRUPT RETURN ADDRESS
AIO.UNI EQU     41061A          CURRENT DEVICE
*
MI.JMP  EQU     303Q
* Ports for H8-4
LP4     EQU     0E0H
TX4     EQU     LP4
RX4     EQU     LP4
DVL4    EQU     LP4
DVH4    EQU     LP4+1
IER4    EQU     LP4+1
LCNTL4  EQU     LP4+3
MCNTL4  EQU     LP4+4
LSTAT4  EQU     LP4+5
*
TX5     EQU     350Q
RX5     EQU     350Q
LSTAT5  EQU     TX5+5
*
        ORG     USERFWA
*
START   EQU     *
        LXI     D,BUFSIZ
        LXI     H,SECBUF
        CALL    ZEROMEM
* DISMOUNT ALL DRIVES
        LXI     H,DEV1
        SCALL   .DMNMS
        LXI     H,DEV2
        SCALL   .DMNMS
        LXI     H,DEV3
        SCALL   .DMNMS
*
        CALL    SINT
*
        JMP     BEGIN
*
* SETUP LPT PORT FOR XXXX,8N2
*
SINT    EQU     *
        XRA     A
        OUT     LCNTL4
        OUT     IER4
        OUT     MCNTL4
        DCR     A
        OUT     LCNTL4
        MVI     A,BAUDIV
        OUT     DVL4
        XRA     A
        OUT     DVH4
        MVI     A,07H
        OUT     LCNTL4
        IN      LSTAT4
        IN      RX4
        RET
*
* SEND A CHAR IN (A) TO THE LP PORT (340Q)
*
CHROUT  PUSH    PSW
CHRO4   IN      LSTAT4
        ANI     60H
        CPI     60H
        JNZ     CHRO4
        POP     PSW
        OUT     TX4
        RET
*
* READ A CHAR FROM THE LP PORT (340Q)
*
CHRIN   IN      LSTAT4
        RAR
        JNC     CHRIN
        IN      RX4
        RET
*
CHRRDY  IN      LSTAT4
        RAR
        RET                     Returns NC = no char, C = char ready
* DIRECT OUT TO CONSOLE PORT
OUT350  PUSH    PSW
OUT35A  IN      LSTAT5
        ANI     60H
        CPI     60H
        JNZ     OUT35A
        POP     PSW
        OUT     TX5
        RET
*
ZEROMEM EQU     *
        XRA     A
        MOV     M,A
        INX     H
        DCX     D
        MOV     A,E
        ORA     D
        JNZ     ZEROMEM
        RET
* FLIP LATCH TO COMMAND MODE
H37CMD  EQU     *
        MVI     A,CON.CD
        OUT     DK.INT
        RET
* FLIP LATCH TO SECTOR/TRACK MODE
H37TRK  EQU     *
        MVI     A,CON.ST
        OUT     DK.INT
        RET
*
BITS    EQU     *
        PUSH    B
        PUSH    PSW
        MVI     A,10000000B
        INR     B
BITS1   RLC
        DCR     B
        JNZ     BITS1
        MOV     C,A
        POP     PSW
        ORA     C
        POP     B
        RET
* INT4 ROUTINE
MYINT   EQU     *
        IN      FD.STAT
        POP     H
        LHLD    BLKICW
        EI
        PCHL
*
RSTBSY  EQU     *
        MVI     A,FDC.FI
        OUT     FD.CMD
        MVI     A,1
        CALL    DLY
        IN      FD.STAT
        RET
* DISK DRIVE UNIT TO WD1797 BITS
UNIBITS EQU     *
        LDA     AIO.UNI
        ADI     4
        MOV     B,A
        XRA     A
        CALL    BITS
        RET
* SELECT AIO.UNI
SELDRV  EQU     *
        PUSH    B
        CALL    H37CMD
        CALL    SETDENS
        EI
        MVI     A,300/2
        CALL    DLY
        POP     B
        RET
* SET DENSITY FROM (DENS)
SETDENS EQU     *
        CALL    UNIBITS         A=DRIVE BIT
        ORI     CON.MO+CON.EI
        MOV     C,A
        LDA     DENS            CON.MFM OR 0
        ORA     C
        STA     CONCMD          DS0+CON.MO+CON.EI+CON.MFM
        OUT     DK.CON
        RET
*
SETMFM  EQU     *
        MVI     A,CON.MFM
        STA     DENS
        JMP     SETDENS
*
SETFM   EQU     *
        MVI     A,0
        STA     DENS
        JMP     SETDENS
* SWITCH DENSITY FM<->MFM
CHGDENS EQU     *
        LDA     DENS
        CPI     CON.MFM
        JZ      SETFM
        JMP     SETMFM
* DESELECT ALL DRIVES
DSLDRV  EQU     *
        PUSH    PSW
        MVI     A,FDC.FI
        OUT     FD.CMD
        XRA     A
        OUT     DK.CON
        POP     PSW
        RET
* 40MS DELAY
DLY40   EQU     *
        PUSH    PSW
        PUSH    B
        LXI     B,3200
DLY40A  DCX     B
        MOV     A,B
        ORA     C
        JNZ     DLY40A
        POP     B
        POP     PSW
        RET
* SET UP INTERRUPT 4 VECTOR
SUPINT  EQU     *
        LXI     H,MYINT
        SHLD    UIVEC+9+1
        MVI     A,MI.JMP
        STA     UIVEC+9
        RET
* WAIT HERE UNTIL INTERRUPT JUMPS TO BLKICW
WAITINT EQU     *
        JMP     WAITINT
* C=TRACK
STPIN   EQU     *
        CALL    SELDRV
        LXI     H,STPI2
        SHLD    BLKICW
STPI1   EQU     *
        MVI     A,FDC.STI+FDF.S20
        OUT     FD.CMD
        JMP     WAITINT
STPI2   EQU     *
        LDA     CURTRK
        INR     A
        STA     CURTRK
        CMP     C
        JNZ     STPI1
        CALL    DLY40
        RET
* C=TRACK
STPOUT  EQU     *
        CALL    SELDRV
        LDA     CURTRK
        ORA     A
        JZ      SEEK0
        LXI     H,STPO2
        SHLD    BLKICW
STPO1   EQU     *
        MVI     A,FDC.STO+FDF.S20
        OUT     FD.CMD
        JMP     WAITINT
STPO2   EQU     *
        LDA     CURTRK
        DCR     A
        STA     CURTRK
        CMP     C
        JNZ     STPO1
        CALL    DLY40
        RET
* SEEK TO TRACK 0
SEEK0   EQU     *
        CALL    SELDRV
        XRA     A
        STA     CURTRK
        LXI     H,SEEKD
        SHLD    BLKICW
        MVI     A,FDC.RST+FDF.S20
        OUT     FD.CMD
        JMP     WAITINT
SEEKD   EQU     *
        MVI     E,10            STEP IN 10 TIMES
        LXI     H,SEEKD2
        SHLD    BLKICW
SEEKD1  EQU     *
        MVI     A,FDC.STI+FDF.S20
        OUT     FD.CMD
        JMP     WAITINT
SEEKD2  EQU     *
        DCR     E
        JNZ     SEEKD1
* DOUBLE RESTORE
        LXI     H,SEEKD3
        SHLD    BLKICW
        MVI     A,FDC.RST+FDF.S20
        OUT     FD.CMD
        JMP     WAITINT
SEEKD3  EQU     *
        CALL    DLY40           HEAD SETTLE TIME
        ANI     FDS.TK0
        RNZ
        STC
        RET
* C=TRK (STEP IN OR OUT TO REACH TARGET)
SEEKTO  EQU     *
        CALL    H37TRK
        MOV     A,C
        OUT     FD.TRK          SET TRACK REGISTER
        LDA     CURTRK
        SUB     C
        RZ                      ALREADY AT TRK C
        JC      STPIN
        JMP     STPOUT
* DE=BUFFER - READ TRACK INTO BUFFER
READLP  EQU     *
        LXI     B,0             TOTAL BYTES READ
        LXI     H,READL2        RETURN ADDRESS
        SHLD    BLKICW
        CALL    H37CMD
        LDA     CONCMD
        ORI     CON.DRQ
        OUT     DK.CON
* RDS=READ SECTOR
* DLF=15MS DELAY
* MRF=READ TO END OF TRACK
* SLF=SECTOR LEN SHIFT (128,256,512,1024)
* SS1=SIDE 1 FLAG
        XRA     A
        LDA     SIDE            0=SIDE 1,1=SIDE 2
        RAL                     IF A=1 THEN RAL=FDF.SS1
        ORI     FDC.RDS+FDF.DLF+FDF.MRF+FDF.SLF
        OUT     FD.CMD
        LXI     H,READL1
READL1  EQU     *               LOOP UNTIL IRQ4
        HLT                     WAIT FOR DRQ
        IN      FD.DAT
        STAX    D
        INX     D
        INX     B
        PCHL                    LOOP BACK TO READL1
READL2  EQU     *
        MVI     A,CON.MO
        OUT     DK.CON
        MOV     L,C
        MOV     H,B
        SHLD    RDCNT
        CALL    H37TRK
        IN      FD.SEC
        DCR     A
        STA     SPERT
        ORA     A               SECTORS PER TRACK == 0?
        RNZ                     NO ERRORS
        STC                     ERROR, SET CARRY FLAG
        RET
* B=SEC (1-255),C=TRK (0-255)
READS   EQU     *
        CALL    H37TRK
        MOV     A,B
        OUT     FD.SEC          SET SECTOR REGISTER
        CALL    SEEKTO
        LXI     D,SECBUF
        JMP     READLP
*
* IMAGER COMMANDS
* R = READ IMAGE SEND TO HOST
* W = WRITE IMAGE FROM HOST
* 0 = DK0
* 1 = DK1
* 4 = 1S40T
* 5 = 2S40T
* 6 = 1S80T
* 7 = 2S80T
* A = SIDE 1
* B = SIDE 2
* E = EXAMINE TRACK
* Q = QUERY DISK TYPE
* T = QUERY TRACK HEADER
*
BEGIN   EQU     *
        CALL    $TYPTX
        DB      0AH,'H37IMGR 2021.09.30 BY LES BIRD',0AH
        DB      'SOFT SECTOR DISK IMAGING PROGRAM',0AH
        DB      'DRIVE CONFIGURATION SHOULD BE AS FOLLOWS:',0AH
        DB      'DK0: DS 40 TRACK',0AH
        DB      'DK1: DS 80 TRACK',8AH
        CALL    H37CMD
        CALL    RSTBSY
        CALL    SUPINT
        XRA     A               SET DRIVE UNIT TO 0
        STA     AIO.UNI
        INR     A
        STA     NUMSID          SINGLE SIDE IS DEFAULT
        MVI     A,40
        STA     NUMTRK          40 TRACK IS DEFAULT
        CALL    SELDRV
        CALL    SEEK0           SEEK TRACK 0
BEGLP   EQU     *
        CALL    $TYPTX
        DB      'WAITING FOR COMMAND:',80H
        CALL    DSLDRV
BEGLP1  EQU     *
        CALL    CHRIN           WAIT FOR COMMAND FROM LP PORT
        CPI     'R'             READ DISK IMAGE
        JZ      CMDRDI
        CPI     'W'
        JZ      CMDWDI
        CPI     '0'
        JZ      SETDK0
        CPI     '1'
        JZ      SETDK1
        CPI     '3'             IDENTIFY AS H37IMGR
        JZ      ISH37
        CPI     '4'
        JZ      SET1S4
        CPI     '5'
        JZ      SET2S4
        CPI     '6'
        JZ      SET1S8
        CPI     '7'
        JZ      SET2S8
        CPI     'Q'
        JZ      QUERY
        CPI     'T'
        JZ      GETTRK
        CPI     'E'
        JZ      EXMTRK
        CPI     'A'
        JZ      SETSID1
        CPI     'B'
        JZ      SETSID2
        MVI     A,'?'
        CALL    CHROUT
        JMP     BEGLP1
* CMD READ DISK IMAGE
CMDRDI  EQU     *
        CALL    $TYPTX
        DB      'READ DISK IMAGE',8AH
        CALL    SELDRV
        XRA     A
        STA     SIDE            INITIALIZE SIDE
        LXI     B,0100H         START SECTOR 1, TRACK 0
CMDRD1  EQU     *
        CALL    CHRIN           WAIT FOR REQUEST
        CPI     'R'
        JNZ     BEGLP           NOT 'R' SO PROBABLY ABORT
        PUSH    B
        MVI     A,'R'
        CALL    OUT350
*
        CALL    READS           READ TRACK
*
        MVI     A,08H
        CALL    OUT350
        MVI     A,'S'
        CALL    OUT350          SHOW SENDING BUFFER
*
        CALL    SENDT           SEND TRACK BUFFER
*
        MVI     A,08H
        CALL    OUT350
        MVI     A,'*'
        CALL    OUT350          SHOW TRACK SENT
        POP     B               GET SEC,TRK
        LDA     NUMSID          1 OR 2
        DCR     A
        JZ      CMDRD2          SINGLE SIDED
        LDA     SIDE            0 OR 1
        ORA     A
        JNZ     CMDRD2          FINISHED SIDE 2
        INR     A
        STA     SIDE
        JMP     CMDRD1          READ SIDE 2
CMDRD2  EQU     *
        XRA     A
        STA     SIDE            SET SIDE 1
        INR     C
        LDA     NUMTRK
        CMP     C
        JNZ     CMDRD1
        MVI     A,0DH
        CALL    OUT350
        MVI     A,0AH
        CALL    OUT350
        JMP     BEGLP
* SEND TRACK DATA TO 340Q
SENDT   EQU     *
        LHLD    RDCNT
        MOV     A,L
        CALL    CHROUT
        MOV     A,H
        CALL    CHROUT
        LDA     SPERT
        CALL    CHROUT
        MOV     A,L
        ORA     H
        JZ      SENDT2
        LXI     D,SECBUF
SENDT1  EQU     *
        LDAX    D
        CALL    CHROUT
        INX     D
        DCX     H
        MOV     A,L
        ORA     H
        JNZ     SENDT1
SENDT2  EQU     *
        MVI     A,'R'
        CALL    CHROUT          HANDSHAKE
        RET
* COMMAND WRITE DISK IMAGE
CMDWDI  EQU     *
        RET
* COMMAND SET DRIVE 0
SETDK0  EQU     *
        PUSH    PSW
        CALL    $TYPTX
        DB      'SET DK0',8AH
        XRA     A
        STA     AIO.UNI
        CALL    SEEK0
        POP     PSW
        CALL    CHROUT          HANDSHAKE
        JMP     BEGLP
* COMMAND SET DRIVE 1
SETDK1  EQU     *
        PUSH    PSW
        CALL    $TYPTX
        DB      'SET DK1',8AH
        MVI     A,1
        STA     AIO.UNI
        CALL    SEEK0
        POP     PSW
        CALL    CHROUT
        JMP     BEGLP
* H37 IMAGER IDENTIFIER
ISH37   EQU     *
        CALL    CHROUT
        CALL    $TYPTX
        DB      'IDENTIFY AS H37IMGR',8AH
        JMP     BEGLP
* SET DRIVE PARAMETERS (SIDES,TRACKS)
SETPAR  EQU     *
        MOV     A,B
        STA     NUMSID
        MOV     A,C
        STA     NUMTRK
        RET
* COMMAND SET SS 40 TRACK
SET1S4  EQU     *
        PUSH    PSW
        CALL    $TYPTX
        DB      'SET SS 40 TRACK',8AH
        LXI     B,0128H
        CALL    SETPAR
        XRA     A
        STA     AIO.UNI
        POP     PSW
        CALL    CHROUT
        JMP     BEGLP
* COMMAND SET DS 40 TRACK
SET2S4  EQU     *
        PUSH    PSW
        CALL    $TYPTX
        DB      'SET DS 40 TRACK',8AH
        LXI     B,0228H
        CALL    SETPAR
        XRA     A
        STA     AIO.UNI
        POP     PSW
        CALL    CHROUT
        JMP     BEGLP
* COMMAND SET SS 80 TRACK
SET1S8  EQU     *
        PUSH    PSW
        CALL    $TYPTX
        DB      'SET SS 80 TRACK',8AH
        LXI     B,0150H
        CALL    SETPAR
        MVI     A,1
        STA     AIO.UNI
        POP     PSW
        CALL    CHROUT
        JMP     BEGLP
* COMMAND SET DS 80 TRACK
SET2S8  EQU     *
        PUSH    PSW
        CALL    $TYPTX
        DB      'SET DS 80 TRACK',8AH
        LXI     B,0250H
        CALL    SETPAR
        MVI     A,1
        STA     AIO.UNI
        POP     PSW
        CALL    CHROUT
        JMP     BEGLP
* COMMAND QUERY DISK TYPE
QUERY   EQU     *
        CALL    CHROUT
        CALL    $TYPTX
        DB      'QUERY DISK TYPE',8AH
        LXI     B,0             SEC,TRK=0
        CALL    QUERY1
        CALL    QUERYR
        JMP     BEGLP
QUERYR  EQU     *
        LDA     SPERT           SECTORS PER TRACK
        CALL    CHROUT
* READ ADDRESS RESULTS
        LDA     QTRK            TRACK
        CALL    CHROUT
        LDA     QSID            SIDE
        CALL    CHROUT
        LDA     QSEC            SECTOR
        CALL    CHROUT
        LDA     QSECL           SECTOR LENGTH
        CALL    CHROUT
        LDA     QCRC1           CRC 1
        CALL    CHROUT
        LDA     QCRC2           CRC 2
        CALL    CHROUT
* DISK PARAMETERS
        LDA     NUMSID          NUM SIDES
        CALL    CHROUT
        LHLD    RDCNT
        MOV     A,L             RDCNT LOW BYTE
        CALL    CHROUT
        MOV     A,H             RDCNT HIGH BYTE
        CALL    CHROUT
        LDA     DENS            DENSITY CON.MFM OR 0
        CALL    CHROUT
        RET
* READ/DETERMINE DISK TYPE
QUERY1  EQU     *
        XRA     A
        STA     SPERT
        MVI     A,CON.MFM       TEST MFM FIRST
        STA     DENS
        CALL    SELDRV
        LXI     D,BUFSIZ
        LXI     H,SECBUF
        CALL    ZEROMEM
QUERYL  EQU     *
        MVI     A,2
        STA     NUMSID          DOUBLE SIDED DEFAULT
        DCR     A
        STA     SIDE
        MOV     B,A             SECTOR 1, C=TRK
        CALL    READS           TEST READ SIDE 2
        PUSH    PSW
        XRA     A
        STA     SIDE
        POP     PSW
        JNC     QUERYS          GOOD DOUBLE SIDE READ
        MVI     A,1
        STA     NUMSID          SINGLE SIDED DISK
        MOV     B,A
        LDA     CURTRK
        MOV     C,A
        CALL    READS           READ A TRACK FILL SPERT+RDCNT
        JNC     QUERYS          GOOD SINGLE SIDE READ
        LDA     DENS
        CPI     CON.MFM
        JNZ     QUERY3          FAILED MFM AND FM
        CALL    $TYPTX
        DB      'CHECKING SINGLE DENSITY',8AH
        CALL    CHGDENS         MIGHT BE FM
        LDA     CURTRK
        MOV     C,A
        JMP     QUERYL
* JUST READ THE HEADER
QUERYS  EQU     *
        CALL    H37CMD
        LXI     H,QUERY3
        SHLD    BLKICW
        LDA     CONCMD
        ORI     CON.DRQ
        OUT     DK.CON
        LXI     B,0
        LXI     D,QBUF
        LXI     H,QUERY2
        XRA     A
        ORI     FDC.RDA+FDF.DLF
        OUT     FD.CMD
QUERY2  EQU     *               LOOP UNTIL IRQ4
        HLT                     WAIT FOR DRQ
        IN      FD.DAT
        STAX    D
        INX     D
        INX     B
        PCHL
QUERY3  EQU     *
        MVI     A,FDC.FI
        OUT     FD.CMD
        IN      FD.DAT
        MVI     A,CON.MO
        OUT     DK.CON
        MOV     A,C
        ORA     B
        RNZ
        STC
        RET
* GET TRACK HEADER
GETTRK  EQU     *
        CALL    CHROUT          HANDSHAKE
        CALL    CHRIN           GET TRACK TO CHECK
        MOV     C,A             STORE TRACK
        PUSH    B
        CALL    $TYPTX
        DB      'QUERY TRACK',8AH
        POP     B
        CALL    GETTR0
        CALL    QUERYR
        JMP     BEGLP
GETTR0  EQU     *
        CALL    SETMFM
GETTR1  EQU     *
        CALL    QUERYS
        JNC     GETTR3
        LDA     DENS
        ORA     A
        JZ      GETTR2
        CALL    $TYPTX
        DB      'TRY SINGLE DENSITY',8AH
        CALL    SETFM
        LDA     CURTRK
        MOV     C,A
        JMP     GETTR1
GETTR2  EQU     *
        CALL    $TYPTX
        DB      'DISK NOT RECOGNIZED',8AH
        STC
GETTR3  EQU     *
        RET
*
EXMTRK  EQU     *
        CALL    CHROUT          HANDSHAKE
        CALL    CHRIN
        MOV     C,A             TRACK TO READ
        CALL    QUERY1
        CALL    SENDT
        CALL    QUERYR
        JMP     BEGLP
*
SETSID1 EQU     *
        CALL    CHROUT
        CALL    $TYPTX
        DB      'SET SIDE 1',8AH
        XRA     A
        STA     SIDE
        JMP     BEGLP
*
SETSID2 EQU     *
        CALL    CHROUT
        CALL    $TYPTX
        DB      'SET SIDE 2',8AH
        MVI     A,1
        STA     SIDE
        JMP     BEGLP
*
FMTTRK  EQU     *
        LDA     DENS
        ORA     A
        JNZ     FMTDD
* SINGLE DENSITY FORMAT
FMTSD   EQU     *
        LXI     D,SDTT
        RET
* DOUBLE DENSITY FORMAT
FMTDD   EQU     *
        MVI     A,16
        STA     SPERT
        MVI     A,1
        STA     DDSEC           START SECTOR 1
        LDA     CURTRK
        STA     DDTRK
        LDA     SIDE
        STA     DDSID
        LXI     D,SECBUF
        LXI     H,DDTT
FMTDD1  EQU     *
        MOV     A,M
        INX     H
        MOV     C,M
        INX     H
        ORA     C
        JZ      FMTDD2          END OF SECTOR DATA
        CALL    WDAT
        JMP     FMTDD1
FMTDD2  EQU     *
        LDA     SPERT
        INR     A
        MOV     C,A
        LDA     DDSEC
        INR     A
        STA     DDSEC
        CMP     C
        JNZ     FMTDD1
* WRITE THE TRACK
WRTTRK  EQU     *
        LDA     CONCMD
        ORI     CON.DRQ
        OUT     DK.CON
        MVI     A,FDC.WTT+FDF.DLF
        MOV     L,A
        LDA     SIDE
        ORA     A
        JZ      WRTTR1
        MVI     A,FDF.SS1
        ORA     L
WRTTR1  EQU     *
        LXI     H,WRTTR3
        SHLD    BLKICW
        LXI     H,WRTTR2
        LXI     D,SECBUF
        OUT     FD.CMD
WRTTR2  EQU     *
        HLT
        LDAX    D
        OUT     FD.DAT
        INX     D
        PCHL
WRTTR3  EQU     *
        MVI     A,150           WRITE GATE DELAY
WRTTR4  DCR     A
        JNZ     WRTTR4
        LDA     CONCMD
        OUT     DK.CON
        RET
*
WDAT    STAX    D
        INX     D
        DCR     C
        JNZ     WDAT
        RET
*
DEV1    DB      'SY0:',0
DEV2    DB      'SY1:',0
DEV3    DB      'SY2:',0
*
CURTRK  DB      0               0-79
CURSEC  DB      0               1-16
SIDE    DB      0               0 OR 1
CONCMD  DB      0               LAST COMMAND SENT TO DK.CON
DENS    DB      CON.MFM
*
SPERT   DB      0               SECTORS PER TRACK
RDCNT   DW      0               BYTES READ
NUMTRK  DB      0               NUM TRACKS (40 OR 80)
NUMSID  DB      0               NUM SIDES (1 OR 2)
*
QBUF    EQU     *
QTRK    DB      0
QSID    DB      0
QSEC    DB      0
QSECL   DB      0
QCRC1   DB      0
QCRC2   DB      0
*
DDTT    DB      04EH,40
DDTTA   DB      0,12
        DB      0F5H,3
        DB      0FEH,1
DDTRK   DB      0,1
DDSID   DB      0,1
DDSEC   DB      0,1
        DB      1,1
        DB      0F7H,1
        DB      04EH,22
        DB      0,12
        DB      0F5H,3
        DB      0FBH,1
DDDP1   DB      0E5H,128
DDDP2   DB      0E5H,128
        DB      0F7H,1
        DB      04EH,43
        DB      0,0

SDTT    DB      0FFH,32
SDTTA   DB      0,6
        DB      0FEH,1
SDTRK   DB      0,1
SDSID   DB      0,1
SDSEC   DB      0,1
        DB      1,1
        DB      0F7H,1
        DB      0FFH,11
        DB      0,6
        DB      0FBH,1
SDDP1   DB      0E5H,128
SDDP2   DB      0E5H,128
        DB      0F7H,1
        DB      0FFH,16
        DB      0,0
*
* HEATH 5.25
* FM =10 SECTORS, 256 BYTES (2560 BYTES PER TRACK)
* MFM=16 SECTORS, 256 BYTES (4096 BYTES PER TRACK)
* PC 5.25
* MFM= 9 SECTORS, 512 BYTES (4608 BYTES PER TRACK)
*
SECBUF  DS      BUFSIZ          MAX FULL TRACK
*
        END     START
