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
BAUDIV  EQU     03H             38400 BAUD IS DEFAULT
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
        XRA     A
        CALL    ZEROBUF
* DISMOUNT ALL DRIVES
        LXI     H,DEVSY0
        SCALL   .DMNMS
        LXI     H,DEVSY1
        SCALL   .DMNMS
        LXI     H,DEVSY2
        SCALL   .DMNMS
        LXI     H,DEVDK0
        SCALL   .DMNMS
        LXI     H,DEVDK1
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
ZEROBUF EQU     *
        PUSH    D
        PUSH    H
        LXI     D,BUFSIZ
        LXI     H,SECBUF
        CALL    ZEROMEM
        POP     H
        POP     D
        RET
* A=BYTE
* HL=MEM
* DE=SIZE
ZEROMEM EQU     *
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
        CALL    H37CMD
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
        CALL    SETDENS
        LDA     CONCMD
        OUT     DK.CON
        EI
        MVI     A,300/2
        CALL    DLY
        POP     B
        RET
* SET DENSITY FROM (DENS)
SETDENS EQU     *
        PUSH    B
        CALL    UNIBITS         A=DRIVE BIT
        ORI     CON.MO+CON.EI
        MOV     C,A
        LDA     DENS            CON.MFM OR 0
        ORA     C
        STA     CONCMD          DS0+CON.MO+CON.EI+CON.MFM
        POP     B
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
        ORA     A
        JNZ     SETFM
        JMP     SETMFM
* DESELECT ALL DRIVES
DSLDRV  EQU     *
        MVI     A,FDC.FI
        OUT     FD.CMD
        XRA     A
        OUT     DK.CON
        RET
* 40MS DELAY
DLY40   EQU     *
        PUSH    B
        LXI     B,3200
DLY40A  DCX     B
        MOV     A,B
        ORA     C
        JNZ     DLY40A
        POP     B
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
        PUSH    PSW
        CALL    DLY40           HEAD SETTLE TIME
        POP     PSW
        ANI     FDS.TK0
        RNZ
        STC
        RET
* C=TRK (STEP IN OR OUT TO REACH TARGET)
SEEKTO  EQU     *
        CALL    H37TRK
        MOV     A,C
        OUT     FD.TRK          SET TRACK REGISTER
        CALL    H37CMD
        LDA     CURTRK
        SUB     C
        RZ                      ALREADY AT TRK C
        JC      STPIN
        JMP     STPOUT
* DE=BUFFER - READ TRACK INTO BUFFER
READLP  EQU     *
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
        MOV     C,A             C=SIDE BIT
        LDA     RDMODE
        ORA     A
        JZ      READL0
        MVI     A,FDC.RDT       READ WHOLE TRACK
        JMP     READL9
READL0  EQU     *
        MVI     A,FDC.RDS+FDF.DLF+FDF.MRF+FDF.SLF
READL9  EQU     *
        ORA     C               ADD IN SIDE BIT
        LXI     B,0
        LXI     D,SECBUF
        LXI     H,READL1
        OUT     FD.CMD
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
        IN      FD.SEC          GET TOTAL SECTORS
        DCR     A
        STA     SPERT
        CALL    H37CMD
        LDA     SPERT
        ORA     A               SECTORS PER TRACK == 0?
        RNZ                     NO ERRORS
        STC                     ERROR, SET CARRY FLAG
        RET
* B=SEC (1-255),C=TRK (0-255)
READS   EQU     *
        XRA     A
        STA     RDMODE
        CALL    H37TRK
        MOV     A,B
        OUT     FD.SEC          SET SECTOR REGISTER
        CALL    SEEKTO
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
        CPI     'F'
        JZ      FMTDSK
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
        MVI     A,'R'
        CALL    CHROUT
*
        MVI     A,08H
        CALL    OUT350
        MVI     A,'.'
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
        MOV     A,C
        CPI     39
        JNZ     CMDRD3
* WRAP LINE AT TRACK 80
        MVI     A,'.'
        CALL    OUT350
        MVI     A,0DH
        CALL    OUT350
        MVI     A,0AH
        CALL    OUT350
CMDRD3  EQU     *
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
        CALL    SEEK0
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
        RZ
        LXI     D,SECBUF
SENDT1  EQU     *
        LDAX    D
        CALL    CHROUT
        INX     D
        DCX     H
        MOV     A,L
        ORA     H
        JNZ     SENDT1
        RET
* COMMAND WRITE DISK IMAGE
CMDWDI  EQU     *
        PUSH    PSW
        CALL    $TYPTX
        DB      'WRITE DISK IMAGE',8AH
        POP     PSW
* MAKE SURE NO CHRIN DROPPED
        DI                      38,400 BAUD DI
        CALL    CHROUT          HANDSHAKE
        CALL    CHRIN           GET SPT
        STA     SPERT
        CALL    CHRIN           GET SSZ
        STA     SSIZE
        CALL    CHRIN           GET DENS (0 OR CON.MFM)
        MOV     C,A
        CALL    CHRIN           GET HIGHBYTE COUNT
        MOV     H,A
        CALL    CHRIN           GET LOWBYTE COUNT
        MOV     L,A
        SHLD    RDCNT
        EI                      38,400 BAUD EI
        MOV     A,H
        ADI     'A'
        CALL    OUT350
        MOV     A,L
        ADI     'A'
        CALL    OUT350
        CALL    SETMFM
        XRA     A
        STA     SIDE
        MOV     A,C             EVALUATE DENSITY
        ORA     A
        JZ      CMDWDS
        CALL    $TYPTX
        DB      'DOUBLE DENSITY',8AH
        CALL    SETFMTD
        JMP     CMDWD0
CMDWDS  EQU     *
        CALL    $TYPTX
        DB      'SINGLE DENSITY',8AH
        CALL    SETFM
        CALL    SETFMTS
CMDWD0  EQU     *
        CALL    SETTRB
        JC      CMDWDE          ERROR SPERT NOT SUPPORTED
        LXI     B,0
CMDWD1  EQU     *
        PUSH    B
        MVI     A,'F'
        CALL    OUT350
        CALL    FMTTRK
        MVI     A,8
        CALL    OUT350
        MVI     A,'R'
        CALL    OUT350
* ASK FOR SECTOR DATA
        DI
        MVI     A,'W'
        CALL    CHROUT
        CALL    CHRIN           WAIT FOR 'W' - DATA FOLLOWS
        LHLD    RDCNT
        LXI     D,SECBUF
* FILL SECBUF WITH TRACK DATA
CMDWD2  EQU     *
        CALL    CHRIN
        STAX    D
        INX     D
        DCX     H
        MOV     A,L
        ORA     H
        JNZ     CMDWD2
        EI
        MVI     A,8
        CALL    OUT350
        MVI     A,'|'
        CALL    OUT350
        MVI     A,1
        STA     CURSEC
        LXI     D,SECBUF
* WRITE DATA TO DISK
CMDWD3  EQU     *               SECTOR LOOP
        CALL    H37TRK
        LDA     CURTRK
        OUT     FD.TRK
        LDA     CURSEC
        OUT     FD.SEC
        CALL    H37CMD
        LDA     CONCMD          DS0+CON.MO+CON.EI+CON.MFM
        ORI     CON.DRQ
        OUT     DK.CON
        LXI     H,CMDWD5
        SHLD    BLKICW
        MVI     A,FDC.WTS+FDF.SLF+FDF.DLF
        MOV     C,A
        LDA     SIDE            0 OR 1
        RAL
        ORA     C
        LXI     B,0
        LXI     H,CMDWD4
        OUT     FD.CMD
*       JMP     CMDWD5
CMDWD4  EQU     *               WRITE SECTOR DATA
        HLT
        LDAX    D
        OUT     FD.DAT
        INX     D
        INX     B
        PCHL
*
CMDWD5  EQU     *
        LDA     CONCMD
        OUT     DK.CON
        LDA     SPERT
        MOV     L,A
        LDA     CURSEC
        CMP     L
        JZ      CMDWD6
        INR     A
        STA     CURSEC
        MOV     L,A
        MVI     A,8
        CALL    OUT350
        MOV     A,L
        CALL    BARANI
        CALL    OUT350
        JMP     CMDWD3
* DO NEXT TRACK
CMDWD6  EQU     *
        MVI     A,'W'
        CALL    CHROUT
        MVI     A,8
        CALL    OUT350
        MVI     A,'.'
        CALL    OUT350
        POP     B
        LDA     NUMSID
        CPI     1
        JZ      CMDWD7
        LDA     SIDE
        ORA     A
        JNZ     CMDWD7
        INR     A
        STA     SIDE            SET SIDE 2
        JMP     CMDWD1
* NEXT TRACK
CMDWD7  EQU     *
        MOV     A,C
        CPI     39
        JNZ     CMDWD8
        MVI     A,'.'
        CALL    OUT350
        MVI     A,0DH
        CALL    OUT350
        MVI     A,0AH
        CALL    OUT350
CMDWD8  EQU     *
        XRA     A
        STA     SIDE
        INR     C
        LDA     NUMTRK
        CMP     C
        JZ      CMDWD9
        CALL    STPIN
        JMP     CMDWD1
CMDWD9  EQU     *
        CALL    SEEK0
        JMP     BEGLP
CMDWDE  EQU     *
        CALL    $TYPTX
        DB      0AH,'ERROR SECTORS PER TRACK NOT SUPPORTED',8AH
        MVI     A,'?'
        CALL    CHROUT
        JMP     BEGLP
*
FMTDSK  EQU     *
        PUSH    PSW
        CALL    $TYPTX
        DB      'FORMAT DISK',8AH
        POP     PSW
        DI
        CALL    CHROUT          HANDSHAKE
        CALL    CHRIN           SECS PER TRACK
        STA     SPERT
        CALL    CHRIN           SEC SIZE (0,1,2,3)
        STA     SSIZE
        CALL    CHRIN           DENS (0,4)
        EI
        PUSH    PSW
        CALL    SETMFM
        CALL    SETFMTD
        POP     PSW
        ORA     A
        JNZ     FMTDS1
        CALL    SETFM
        CALL    SETFMTS
FMTDS1  EQU     *
        MVI     A,'F'
        CALL    CHROUT          HANDSHAKE
        CALL    SETTRB
        JC      FMTDS9
        CALL    SEEK0
FMTDS2  EQU     *
        CALL    FMTTRK
        MVI     A,'.'
        CALL    OUT350
        LDA     NUMSID
        DCR     A
        JZ      FMTDS3
        LDA     SIDE
        ORA     A
        JNZ     FMTDS3
        INR     A
        STA     SIDE
        JMP     FMTDS2
FMTDS3  EQU     *
        XRA     A
        STA     SIDE
        LDA     CURTRK
        INR     A
        MOV     C,A
        LDA     NUMTRK
        CMP     C
        JZ      FMTDS9
        CALL    STPIN
        JMP     FMTDS2
FMTDS9  EQU     *
        CALL    $TYPTX
        DB      0AH,'FORMAT COMPLETE',8AH
        CALL    SEEK0
        MVI     A,'F'
        CALL    CHROUT          HANDSHAKE
        JMP     BEGLP
*
SETFMTD EQU     *
        MVI     A,04EH
        CALL    ZEROBUF
        RET
SETFMTS EQU     *
        MVI     A,0FFH
        CALL    ZEROBUF
        RET
* FORMAT FOR DOUBLE/SINGLE DENSITY
FMTTRK  EQU     *
        MVI     A,1
        STA     DDBUFS          START SECTOR 1
        STA     SDBUFS
        LDA     CURTRK
        STA     DDBUFT
        STA     SDBUFT
        LDA     SIDE            0 OR 1
        STA     DDBUFD
        STA     SDBUFD
        LDA     SSIZE
        STA     DDBUFZ
        STA     SDBUFZ
        LXI     D,SECBUF
* BUILD TRACK BUFFER
FMTTR1  EQU     *
        LXI     H,DDBUF
        LDA     DENS
        ORA     A
        JNZ     FMTTR2
        LXI     H,SDBUF
FMTTR2  EQU     *
        MOV     A,M
        INX     H
        MOV     C,M
        INX     H
        CALL    WDAT            TRACK HEADER
FMTTR3  EQU     *
        PUSH    H               SECTOR DATA
FMTTR4  EQU     *
        MOV     A,M
        INX     H
        MOV     C,M
        INX     H
        MOV     B,A
        ORA     C
        JZ      FMTTR5          END OF SECTOR DATA
        MOV     A,B
        CALL    WDAT
        JMP     FMTTR4
FMTTR5  EQU     *
        POP     H
        LDA     SPERT
        INR     A
        MOV     C,A
        LDA     DDBUFS
        INR     A
        STA     DDBUFS
        STA     SDBUFS
        CMP     C
        JNZ     FMTTR3
* WRITE THE TRACK
WRTTRK  EQU     *
        LDA     CONCMD
        ORI     CON.DRQ
        OUT     DK.CON
        MVI     A,FDC.WTT+FDF.DLF
        MOV     L,A
        LDA     SIDE            0 OR 1
        RAL
        ORA     L
        LXI     H,WRTTR3
        SHLD    BLKICW
        LXI     H,WRTTR2
        LXI     D,SECBUF
        LXI     B,0
        OUT     FD.CMD
WRTTR2  EQU     *
        HLT
        LDAX    D
        OUT     FD.DAT
        INX     D
        INX     B
        PCHL
WRTTR3  EQU     *
        MVI     A,150           WRITE GATE DELAY
WRTTR4  DCR     A
        JNZ     WRTTR4
        LDA     CONCMD
        OUT     DK.CON
        XRA     A
        LHLD    RDCNT
        MOV     A,H
        CMP     B
        JNZ     WRTTRE
        MOV     A,L
        CMP     C
        RZ
WRTTRE  EQU     *
        STC
        RET
* SET UP TRACK DEFINITION BASED ON SECTORS PER TRACK
SETTRB  EQU     *
        LDA     SPERT
        LXI     H,DD05
        CPI     5               CPM 05,1024
        JZ      SETTR1
        LXI     H,DD08
        CPI     8               MSDOS 08,512
        JZ      SETTR1
        LXI     H,DD09
        CPI     9               MSDOS 09,512
        JZ      SETTR1
        LXI     H,DD10
        CPI     10              HDOS 10,256
        JZ      SETTR1
        LXI     H,DD16
        CPI     16              HDOS 16,256
        JZ      SETTR1
        STC
        RET
SETTR1  EQU     *
        LXI     B,48
        LXI     D,DDBUF
        LDA     DENS
        ORA     A
        JNZ     CPYBUF
        LXI     D,SDBUF
CPYBUF  EQU     *
        MOV     A,M
        INX     H
        STAX    D
        INX     D
        DCX     B
        MOV     A,C
        ORA     B
        JNZ     CPYBUF
        RET
*
WDAT    STAX    D
        INX     D
        DCR     C
        JNZ     WDAT
        RET
* DO BAR ANIMATION
BARANI  EQU     *
        PUSH    D
        LXI     H,BARS
        MVI     D,0
        MOV     E,A
        DAD     D
        MOV     A,M
        POP     D
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
        CALL    QUERYI
        XRA     A
        STA     SPERT
        STA     NUMSID
        STA     SIDE
        CALL    SETMFM          TRY MFM FIRST
        LXI     B,0104H
        CALL    SEEKTO
QUERY1  EQU     *
        PUSH    B
        CALL    QUERYS          READ ADDRESS
        POP     B
        JNC     QUERY4          GOOD READ
        LDA     DENS
        ORA     A
        JZ      QUERYX          INVALID DISK
        PUSH    B
        CALL    $TYPTX
        DB      'TRY SINGLE DENSITY',8AH
        POP     B
        CALL    SETFM
        JMP     QUERY1
QUERY4  EQU     *
        LDA     QTRK
        CPI     4
        JNZ     QUERYX          WRONG DISK TYPE
        MVI     A,1
        STA     SIDE
        INR     A
        STA     NUMSID          SET 2 SIDED
        PUSH    B
        CALL    QUERYS          TRY SIDE 2
        POP     B
        JNC     QUERY5          2 SIDED GOOD
        MVI     A,1
        STA     NUMSID          ELSE 1 SIDED
QUERY5  EQU     *
        PUSH    B
        CALL    $TYPTX
        DB      'SIDES=',80H
        LDA     NUMSID
        ADI     '0'
        CALL    OUT350
        MVI     A,0DH
        CALL    OUT350
        MVI     A,0AH
        CALL    OUT350
        POP     B
        XRA     A
        STA     SIDE
        CALL    ZEROBUF
        CALL    READS           READ TRACK
QUERYX  EQU     *
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
*
QUERYI  EQU     *
        XRA     A
        STA     QTRK
        STA     QSID
        STA     QSEC
        STA     QSECL
        STA     QCRC1
        STA     QCRC2
        RET
* READ DISK HEADER
QUERYS  EQU     *
        CALL    SELDRV
        LXI     H,QUERY3
        SHLD    BLKICW
        LDA     CONCMD
        ORI     CON.DRQ
        OUT     DK.CON
        LXI     B,0
        LXI     D,QBUF
        LXI     H,QUERY2
        XRA     A
        LDA     SIDE
        RAL
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
        ADI     'A'
        CALL    OUT350
        MVI     A,' '
        CALL    OUT350
        PUSH    B
        CALL    $TYPTX
        DB      'READ TRACK HEADER',8AH
        POP     B
        XRA     A
        STA     SPERT
        STA     NUMSID
        CALL    GETTR0
        CALL    QUERYR
        JMP     BEGLP
GETTR0  EQU     *
        CALL    QUERYI
        CALL    SEEKTO
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
        CALL    CHRIN           GET TRACK
        MOV     C,A
        PUSH    B
        CALL    $TYPTX
        DB      'EXAMINE TRACK',8AH
        POP     B
        CALL    SEEKTO
        MVI     A,1
        STA     RDMODE
        CALL    READLP
        CALL    SENDT
        XRA     A
        STA     RDMODE
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
DEVSY0  DB      'SY0:',0
DEVSY1  DB      'SY1:',0
DEVSY2  DB      'SY2:',0
DEVDK0  DB      'DK0:',0
DEVDK1  DB      'DK1:',0
*
BARS    DB      '|','/','-','\','|','/','-','\'
        DB      '|','/','-','\','|','/','-','\'
        DB      '|','/','-','\','|','/','-','\'
*
CURTRK  DB      0               0-79
CURSEC  DB      0               1-16
SIDE    DB      0               0 OR 1
RDMODE  DB      0               0=SECTORS,1=TRACK
CONCMD  DB      0               LAST COMMAND SENT TO DK.CON
DENS    DB      CON.MFM
*
SPERT   DB      0               SECTORS PER TRACK
SSIZE   DB      0               SECTOR SIZE (0,1,2,3)
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
DDBUF   DB      04EH,40         GAP
DDBUFA  DB      0,12
        DB      0F5H,3          GENERATE 3 A1 BYTES
        DB      0FEH,1          SECTOR HEADER
DDBUFT  DB      0,1             TRACK
DDBUFD  DB      0,1             SIDE
DDBUFS  DB      0,1             SECTOR
DDBUFZ  DB      1,1             SECTOR SIZE (0,1,2,3)
        DB      0F7H,1          GENERATE 2 CRC BYTES
        DB      04EH,22         GAP
        DB      0,12            LEADING ZEROS
        DB      0F5H,3          GENERATE 3 A1 BYTES
        DB      0FBH,1          DATA HEADER
* FOLLOWING DATA WILL CHANGE DEPENDING ON FORMAT
        DB      0E5H,128        DATA 1
        DB      0E5H,128        DATA 2
        DB      0E5H,128        DATA 3
        DB      0E5H,128        DATA 4
        DB      0E5H,128        DATA 5
        DB      0E5H,128        DATA 6
        DB      0E5H,128        DATA 7
        DB      0E5H,128        DATA 8
        DB      0F7H,1          GENERATE 2 CRC BYTES
        DB      04EH,43         GAP
        DB      0,0             END OF SECTOR
*
SDBUF   DB      0FFH,32
SDBUFA  DB      0,6
        DB      0FEH,1
SDBUFT  DB      0,1
SDBUFD  DB      0,1
SDBUFS  DB      0,1
SDBUFZ  DB      1,1
        DB      0F7H,1
        DB      0FFH,11
        DB      0,6
        DB      0FBH,1
        DB      0E5H,128
        DB      0E5H,128
        DB      0F7H,1
        DB      0FFH,16
        DB      0,0             END OF SECTOR
        DB      0,0             PAD TO 48 BYTES
        DB      0,0
        DB      0,0
        DB      0,0
        DB      0,0
        DB      0,0
        DB      0,0
        DB      0,0
* DOUBLE DENSITY
DD05    DB      04EH,40         GAP
        DB      0,12
        DB      0F5H,3
        DB      0FEH,1          SECTOR HEADER
        DB      0,1
        DB      0,1
        DB      0,1
        DB      3,1
        DB      0F7H,1          GENERATE 2 CRC BYTES
        DB      04EH,22
        DB      0,12
        DB      0F5H,3
        DB      0FBH,1          DATA HEADER
        DB      0E5H,128        SECTOR DATA
        DB      0E5H,128        256
        DB      0E5H,128        SECTOR DATA
        DB      0E5H,128        512
        DB      0E5H,128        SECTOR DATA
        DB      0E5H,128
        DB      0E5H,128        SECTOR DATA
        DB      0E5H,128        1024
        DB      0F7H,1          GENERATE 2 CRC BYTES
        DB      04EH,43         GAP
        DB      0,0
* DOUBLE DENSITY
DD08    DB      04EH,40         GAP
        DB      0,12
        DB      0F5H,3
        DB      0FEH,1          SECTOR HEADER
        DB      0,1
        DB      0,1
        DB      0,1
        DB      2,1
        DB      0F7H,1          GENERATE 2 CRC BYTES
        DB      04EH,22
        DB      0,12
        DB      0F5H,3
        DB      0FBH,1          DATA HEADER
        DB      0E5H,128        SECTOR DATA
        DB      0E5H,128        256
        DB      0E5H,128        SECTOR DATA
        DB      0E5H,128        512
        DB      0F7H,1          GENERATE 2 CRC BYTES
        DB      04EH,43         GAP
        DB      0,0
* DOUBLE DENSITY
DD09    DB      04EH,40         GAP
        DB      0,12
        DB      0F5H,3
        DB      0FEH,1          SECTOR HEADER
        DB      0,1
        DB      0,1
        DB      0,1
        DB      2,1
        DB      0F7H,1          GENERATE 2 CRC BYTES
        DB      04EH,22
        DB      0,12
        DB      0F5H,3
        DB      0FBH,1          DATA HEADER
        DB      0E5H,128        SECTOR DATA
        DB      0E5H,128        256
        DB      0E5H,128        SECTOR DATA
        DB      0E5H,128        512
        DB      0F7H,1          GENERATE 2 CRC BYTES
        DB      04EH,43         GAP
        DB      0,0
* SINGLE DENSITY
DD10    DB      0FFH,32
        DB      0,6
        DB      0FEH,1
        DB      0,1
        DB      0,1
        DB      0,1
        DB      1,1
        DB      0F7H,1
        DB      0FFH,11
        DB      0,6
        DB      0FBH,1
        DB      0E5H,128
        DB      0E5H,128
        DB      0F7H,1
        DB      0FFH,16
        DB      0,0
* DOUBLE DENSITY
DD16    DB      04EH,40         GAP
        DB      0,12
        DB      0F5H,3
        DB      0FEH,1          SECTOR HEADER
        DB      0,1
        DB      0,1
        DB      0,1
        DB      1,1
        DB      0F7H,1          GENERATE 2 CRC BYTES
        DB      04EH,22
        DB      0,12
        DB      0F5H,3
        DB      0FBH,1          DATA HEADER
        DB      0AAH,128        SECTOR DATA
        DB      0AAH,128
        DB      0F7H,1          GENERATE 2 CRC BYTES
        DB      04EH,43         GAP
        DB      0,0
*
* HEATH HDOS 5.25
* FM =10 SECTORS, 256 BYTES (2560 BYTES PER TRACK)
* MFM=16 SECTORS, 256 BYTES (4096 BYTES PER TRACK)
* HEATH CPM 5.25
* MFM=5 SECTORS, 1024 BYTES (5120 BYTES PER TRACK)
* PC 5.25
* MFM= 9 SECTORS, 512 BYTES (4608 BYTES PER TRACK)
*
SECBUF  DS      BUFSIZ          MAX FULL TRACK
*
        END     START
