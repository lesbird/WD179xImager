*
* H37IMGR
*
* 2021.09.30 LES BIRD
* SHOULD ALSO WORK FOR PC/Z100 5.25 DISKS (WD179X)
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
BAUDIV  EQU     0CH             9600 BAUD IS DEFAULT
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
*       DI
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
*       EI
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
        PUSH    PSW
        PUSH    B
        CALL    H37CMD
        CALL    SETDENS
        EI
        MVI     A,300/2
        CALL    DLY
        POP     B
        POP     PSW
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
* Q = QUERY DISK TYPE
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
        CPI     '9'
        JZ      B9600
        CPI     '('
        JZ      B19200
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
        LXI     D,SECBUF
SENDT1  EQU     *
        LDAX    D
        CALL    CHROUT
        INX     D
        DCX     H
        MOV     A,L
        ORA     H
        JNZ     SENDT1
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
        CALL    QUERY1
        LDA     SPERT           SECTORS PER TRACK
        CALL    CHROUT
* READ ADDRESS RESULTS
        LDA     SECBUF          TRACK
        CALL    CHROUT
        LDA     SECBUF+1        SIDE
        CALL    CHROUT
        LDA     SECBUF+2        SECTOR
        CALL    CHROUT
        LDA     SECBUF+3        SECTOR LENGTH
        CALL    CHROUT
        LDA     SECBUF+4        CRC 1
        CALL    CHROUT
        LDA     SECBUF+5        CRC 2
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
        JMP     BEGLP
*
QUERY1  EQU     *
        XRA     A
        STA     SPERT
        MVI     A,CON.MFM       TEST MFM FIRST
        STA     DENS
        CALL    SELDRV
QUERYL  EQU     *
        MVI     A,2
        STA     NUMSID          DOUBLE SIDED DEFAULT
        DCR     A
        STA     SIDE
        LXI     B,0100H
        CALL    READS           TEST READ SIDE 2
        PUSH    PSW
        XRA     A
        STA     SIDE
        POP     PSW
        JNC     QUERYS          GOOD DOUBLE SIDE READ
        MVI     A,1
        STA     NUMSID          SINGLE SIDED DISK
        LXI     B,0100H
        CALL    READS           READ A TRACK FILL SPERT+RDCNT
        JNC     QUERYS          GOOD SINGLE SIDE READ
        LDA     DENS
        CPI     CON.MFM
        JNZ     QUERY3          FAILED MFM AND FM
        CALL    $TYPTX
        DB      'CHECKING SINGLE DENSITY',8AH
        CALL    CHGDENS         MIGHT BE FM
        JMP     QUERYL
QUERYS  EQU     *
        CALL    H37CMD
        LXI     H,QUERY3
        SHLD    BLKICW
        LDA     CONCMD
        ORI     CON.DRQ
        OUT     DK.CON
        LXI     B,0
        LXI     D,SECBUF
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
        PUSH    PSW
        MVI     A,FDC.FI
        OUT     FD.CMD
        IN      FD.DAT
        MVI     A,CON.MO
        OUT     DK.CON
        POP     PSW
        RET
* SET 9600 BAUD
B9600   EQU     *
        CALL    $TYPTX
        DB      'SET 9600 BAUD',8AH
        MVI     A,0CH
        STA     BAUDIV
        CALL    SINT
        JMP     BEGLP
* SET 19200 BAUD
B19200  EQU     *
        CALL    $TYPTX
        DB      'SET 19200 BAUD',8AH
        MVI     A,06H
        STA     BAUDIV
        CALL    SINT
        JMP     BEGLP
*
QUIT    EQU     *
        CALL    $TYPTX
        DB      0AH,'GOODBYE',8AH
        CALL    DSLDRV
        XRA     A
        SCALL   .EXIT
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
* HEATH 5.25
* FM =10 SECTORS, 256 BYTES (2560 BYTES PER TRACK)
* MFM=16 SECTORS, 256 BYTES (4096 BYTES PER TRACK)
* PC 5.25
* MFM= 8 SECTORS,1024 BYTES (8192 BYTES PER TRACK)
*
SECBUF  DS      8192            MAX FULL TRACK
*
        END     START
