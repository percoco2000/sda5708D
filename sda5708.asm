;--------------------------------------------;
; Program : SDA5708.asm                      ;
;--------------------------------------------;
; Interfacing a Nokia Dbox 9500S Display     ;
; with a 16F84                               ;
; The display is controlled by a SDA5708     ;
; And is connected on PIC's PORTA            ;
;--------------------------------------------;
; PORTA0 --> Reset                           ;
; PORTA1 --> Load                            ;
; PORTA2 --> Clock                           ;
; PORTA3 --> Data                            ;
;--------------------------------------------; 

; Disable 302 Assembler Message
ERRORLEVEL -302
    
    processor p16f84a
    #include "./p16f84.inc"
    
    ; Config:
    ; Code Protect    OFF
    ; Power Up Timer  ON
    ; Watch Dog Timer OFF
    ; High Speed Oscillator
    __CONFIG _CP_OFF & _PWRTE_ON & _WDT_OFF & _HS_OSC 


; --------------- Defines -------------------
    ; LCD Pinouts
Reset       equ     0
Load        equ     1
Clk         equ     2
Dat         equ     3
 
    ; LCD Registers
;-----------------------------------------------------------------------------    
; CtR is the control register, used to configure the beaviour of the display.
;     Accessed whenever bits 7 & 8 are 1
;     bit 5 is on in normal mode, 0 when issued a clear command
;     bit 3-0 sets the brigtness    
; AdR is the address register, used to set the character to address (0 to 7)
;     Accessed whenever bits 8 and 6 are 1, and bit 7 is 0
;     last 3 bits are used to index the character
; CDR is the cell's pixel, it is automatically incremented
;     is accessed whenever bits 8,7 &6 are 0
;     remaing bits indicate : 1 pixel ON
;                             0 pixel OFF
;     Every character is drawn row by row 
;     the number of rows is 7 and they need to be issued sequentially
;     
                               
CtR         equ     B'11100000'     ; Control Register
AdR         equ     B'10100000'     ; Address Register
CDR         equ     B'00000000'     ; Column Data Register

    
; -------------- Variables ------------------
        
    cblock 0x0C
        COUNT         ; Generic Counter
        COUNT_A       ; used in Delay soubroutine
        LCD_BRIGHT    ; Lcd brightness (Lower Nibble, 0000 = Max brightness)
        LCD_POS       ; Current Cursor Position
        BYTE          ; Byte to sent to LCD
    endc


    org 0x00
  
   ;            Device Configuration
   ; ----------------------------------------
    
    banksel TRISA
        movlw       B'00000000'
        movwf       TRISA           ; PortA all output
        movlw       B'00000001'     
        movwf       TRISB           ; PortB all output
        
    banksel PORTA
        movlw       B'00000011'     ; Reset=HI, Load=HI, Data/Clock=LO 
        movwf       PORTA
        clrf        PORTB
        clrf        LCD_BRIGHT      ; Max brightness
        clrf        LCD_POS         ; Set Cursor to column 0
           
   ;         Main Program
   ; -------------------------------------------------
; Simple test routine
; At every keypress on RB0 send a '0' to the display        
main:
        call        Init_Lcd
Start:        
        btfsc       PORTB,0         ; Key Pressed ?
        goto        $-1             ; No, Wait
        call		Delay2
        btfss		PORTB,0         ; Key Relased
        goto		$-1				; No, Wait
        call 		Delay2
        movlw       0x00            ; Yes, send '0' to display
        call        Send_Char
        
        goto        Start       
        
        
        
   ; ---------------------------------------------------------
   ;                   Soubrotines         

;----------------------------------------;
; Soubroutine : Init_Lcd                 ;
;----------------------------------------;
; Init Lcd display.                      ;
; Issue RESET Signal                     ;
; Cursor to row 0  ( Due to RESET )      ;
; Set The brightness to LCD_BRIGHT       ;
;----------------------------------------;
Init_Lcd:
        bcf         PORTA,Reset     ; Reset!
        call        Delay
        bsf         PORTA,Reset     ; 
        call        Clear_Display   ; 
        return

;----------------------------------------;
; Soubroutine : Clear_Display            ;
;----------------------------------------;
; Clear the display                      ;
; Set The brightness                     ;
;----------------------------------------;
Clear_Display:
        movlw       CtR             ; Set Control Register
        andlw		B'11011111'		; Set Bit 5 = 0 (Clear display)
        call        Send_Byte       ; Issue command  
        call        Set_Brightness  ; Set Brightness (And put Bit 5 to 1)
        return
        
;--------------------------------------------;
; Soubroutine : Set_Brightness               ;
; Usage       : Put Brightness in LCD_BRIGHT ;
;               Call The soubroutine         ;
;--------------------------------------------;
; Set The brightness to LCD_BRIGHT           ;
;--------------------------------------------;
Set_Brightness:
        movlw       CtR             ; Set Control Register
        addwf       LCD_BRIGHT,W    ; Set Brightness
        call        Send_Byte       ; Issue command 
        return

;-------------------------------------------;
; Soubroutine : Set_Position                ;
; Usage       : Put the position in LCD_POS ;
;               and call the soubroutine    ;
;-------------------------------------------;
; Set the cursor position on the display    ;
; At the value in LCD_POS                   ;
; Store the new position in LCD_POS         ;
;-------------------------------------------;
Set_Position:
        movlw       AdR             ; Set Address Register
        addwf       LCD_POS,W       ; Set Position
        call        Send_Byte       ; Issue command 
        return
        
;----------------------------------------;
; Soubroutine : Send_Char                ;
;----------------------------------------;
; Send The character in W to LCD         ;
; Increase the cursor position           ; 
; If cursor > 8 reset to 0               ; 
;----------------------------------------;
Send_Char:
        ;addwf      PCL,F
        goto       Char_0           ; 0
        ;goto       Char_1      ; 1   
        ;goto       Char_2      ; 2
        ;goto       Char_3      ; 3
        ;goto       Char_4      ; 4
        ;goto       Char_5      ; 5
        ;goto       Char_6      ; 6
        ;goto       Char_7      ; 7
        ;goto       Char_8      ; 8
        ;goto       Char_9      ; 9
        
        
Char_0:
        movlw       B'00001110'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00010011'
        call        Send_Byte
        movlw       B'00010101'
        call        Send_Byte
        movlw       B'00011001'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00001110'
        call        Send_Byte
        goto        Char_Sent

Char_Sent:
        incf        LCD_POS,F
        movlw       0x08
        xorwf       LCD_POS,W       
        btfss       STATUS,Z        ; Is LCD_POS=8 ?
        goto        $+2             ; no, skip next instruction
        clrf        LCD_POS
        call        Set_Position 
        return
                   
;----------------------------------------;
; Soubroutine : Send_Byte                ;
; Usage :                                ;
;        movlw  'value'                  ;
;        call   Send_Byte                ;
;----------------------------------------;
; Send the value in W to the LCD         ;
; Put LOAD low                           ;
; And send every bit, on the rising edge ;
; of the clock signal                    ;
;----------------------------------------;
Send_Byte:
        movwf       BYTE             
        movlw       0x08
        movwf       COUNT           ; Init BIT Counter
        bcf         PORTA,Load      ; Set Load low
Loop_Send:        
        btfss       BYTE,0
        bcf         PORTA,Dat
        btfsc       BYTE,0
        bsf         PORTA,Dat
        bsf         PORTA,Clk
        call        Delay
        bcf         PORTA,Clk
        call 		Delay
        bcf         STATUS,C
        rrf         BYTE,F
        decfsz      COUNT,F         ; All 8 bits trasmitted ?
        goto        Loop_Send       ; No, go on
        
        bsf         PORTA,Load      ; Yes, Disable LOAD, and reset DATA
        bcf         PORTA,Dat
        return              
        
;-----------------------------;
;Soubroutine : Delay          ;
;-----------------------------;
; Delay Routine               ;
;-----------------------------;
Delay:
        movlw   0x8
        movwf   COUNT_A
        decfsz  COUNT_A,F
        goto    $-1
        return
        
Delay2:
        call 	Delay
        call	Delay
        
        return
    end
