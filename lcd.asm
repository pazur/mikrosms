.EQU LCD_DATA_PORT = PORTD ; port danych
.EQU LCD_E_PORT    = PORTD ; port linii wyzwalajacej E
.EQU LCD_RS_PORT   = PORTD	; port linii RS
.EQU LCD_DATA_DDR  = DDRD	; LCD_DATA_DDR - rejestr kierunku danych
.EQU LCD_E_DDR     = DDRD  ; LCD_E_DDR - rejestr kierunku linii E
.EQU LCD_RS_DDR    = DDRD  ; LCD_RS_DDR - rejestr kierunku linii RS
.EQU LCD_E         = PD1   ; OE - numer bitu linii OE
.EQU LCD_RS        = PD0   ; RS - numer bitu linii RS
.EQU LCD_D4        = PD2   ; D4 - numer bitu linii D4
.EQU LCD_D5        = PD3   ; D5 - numer bitu linii D5
.EQU LCD_D6        = PD4   ; D6 - numer bitu linii D6
.EQU LCD_D7        = PD5   ; D7 - numer bitu linii D7

lcd_port_init:
    SBI LCD_E_DDR, LCD_E
    SBI LCD_RS_DDR, LCD_RS
    SBI LCD_DATA_DDR, LCD_D4
    SBI LCD_DATA_DDR, LCD_D5
    SBI LCD_DATA_DDR, LCD_D6
    SBI LCD_DATA_DDR, LCD_D7
	 RET

lcd_send:
    NOP
    NOP
    NOP
    CBI LCD_E_PORT, LCD_E
    RET

lcd_send_byte:
	 SBI LCD_E_PORT, LCD_E
	 CBI LCD_DATA_PORT, LCD_D4
	 CBI LCD_DATA_PORT, LCD_D5
	 CBI LCD_DATA_PORT, LCD_D6
	 CBI LCD_DATA_PORT, LCD_D7
	 SBRC R16, 4
	 SBI LCD_DATA_PORT, LCD_D4
	 SBRC R16, 5
	 SBI LCD_DATA_PORT, LCD_D5
	 SBRC R16, 6
	 SBI LCD_DATA_PORT, LCD_D6
	 SBRC R16, 7
	 SBI LCD_DATA_PORT, LCD_D7
	 NOP
	 NOP
	 NOP
	 NOP
	 CBI LCD_E_PORT, LCD_E
	 NOP
	 NOP
	 NOP
	 SBI LCD_E_PORT, LCD_E
	 CBI LCD_DATA_PORT, LCD_D4
	 CBI LCD_DATA_PORT, LCD_D5
	 CBI LCD_DATA_PORT, LCD_D6
	 CBI LCD_DATA_PORT, LCD_D7
	 SBRC R16, 0
	 SBI LCD_DATA_PORT, LCD_D4
	 SBRC R16, 1
	 SBI LCD_DATA_PORT, LCD_D5
	 SBRC R16, 2
	 SBI LCD_DATA_PORT, LCD_D6
	 SBRC R16, 3
	 SBI LCD_DATA_PORT, LCD_D7
	 NOP
	 NOP
	 NOP
	 NOP
	 CBI LCD_E_PORT, LCD_E
	 PUSH R16
	 LDI R16, 4
	 CALL wait_10us
	 POP R16
	 RET

lcd_clear: ;RS should be set to 0
    PUSH R16
    LDI R16, 0b00000001
    CALL lcd_send_byte
    LDI R16, 170
    CALL wait_10us
    POP R16
    RET	 	

lcd_return_home: ;RS should be set to 0
	 PUSH R16
    LDI R16, 0b00000010
    CALL lcd_send_byte
    LDI R16, 170
    CALL wait_10us
    POP R16
    RET

lcd_init:
	 CALL lcd_port_init
    PUSH R16
	 CBI LCD_RS_PORT, LCD_RS
	 CBI LCD_E_PORT, LCD_E
	 LDI R16, 40
	 CALL wait_ms
	 SBI LCD_E_PORT, LCD_E  ; send (30)16
	 SBI LCD_DATA_PORT, LCD_D4
	 SBI LCD_DATA_PORT, LCD_D5
	 CBI LCD_DATA_PORT, LCD_D6
	 CBI LCD_DATA_PORT, LCD_D7
	 CALL lcd_send
	 LDI R16, 5
	 CALL wait_ms
	 SBI LCD_E_PORT, LCD_E ; send (30)16
	 CALL lcd_send
	 LDI R16, 10
	 CALL wait_10us
	 SBI LCD_E_PORT, LCD_E ; send (30)16
	 CALL lcd_send
	 LDI R16, 10
	 CALL wait_10us
	 SBI LCD_E_PORT, LCD_E ; send (20)26
	 CBI LCD_DATA_PORT, LCD_D4
	 CALL lcd_send
	 LDI R16, 4
	 CALL wait_10us
	 LDI R16, 0b00000110 ; entry mode set
	 CALL lcd_send_byte
	 LDI R16, 0b00001111 ; display control
	 CALL lcd_send_byte
	 LDI R16, 0b00010100 ; cursor display set
	 CALL lcd_send_byte
	 LDI R16, 0b00101000 ; function set
	 CALL lcd_send_byte
	 LDI R16, 0b00000010 ; return home
	 CALL lcd_send_byte
	 SBI LCD_RS_PORT, LCD_RS
	 LDI R16, 4
	 CALL wait_ms
	 POP R16
    RET	

lcd_write_number:
	CALL lcd_send_byte
	RET


lcd_write:
	PUSH R16 ;tmp -args to funs
	PUSH R17 ;argument
	PUSH R18 ;current bit
	PUSH R19 ;number read
	PUSH R20 ;tmp2
	LDI R18, 0
lcd_write_loop:
	ROL R20;
	SBRC R17, 0
	SUBI R20, -1
	CPI R20, 10
	BRGE lcd_write_number
	INC R18
	CPI R18, 8
	BRNE lcd_write_loop
	RET
	
	 POP R20;
	 POP R19;
	 POP R18;
	 POP R17;
	 POP R16
	 RET


div_10: ;R16 := R16 div 10 ; R17 := R16 mod 10
	PUSH R19 ; substracted
	PUSH R18 ; added to result
	LDI R19, 160 ; 10 * 2^4
	LDI R18, 16
	LDI R17, 0
 div_10_loop:
	CP R16, R19
	BRLO div_10_loop_lower	
	SUB R16, R19
	ADD R17, R18
  div_10_loop_lower:
	LSR R19
	LSR R18
	CPI R19, 10
	BRGE div_10_loop
	MOV R18, R17
	MOV R17, R16
	MOV R16, R18
	POP R18
	POP R19
	RET

lcd_write_digit: ;writes digit in R17 on lcd
	PUSH R16
	LDI R16, 0b00110000
	ADD R16, R17
	CALL lcd_send_byte
	POP R16
	RET

write_10_reverse: ; writes R16 on lcd
	PUSH R16
	PUSH R17
 write_10_reverse_loop:
	CALL div_10
	CALL lcd_write_digit
	CPI R16, 0
	BRNE write_10_reverse_loop
	
	POP R17
	POP R16
	RET
	
write_10: ;writes R16 on lcd
	PUSH R16
	PUSH R17
	PUSH R18 ;number of digits
	LDI R18, 0
 write_10_loop:
   CALL div_10
   PUSH R17
   INC R18
   CPI R16, 0
   BRNE write_10_loop
 write_10_single_digit:
   POP R17
   DEC R18
   CALL lcd_write_digit
   CPI R18, 0
   BRNE write_10_single_digit	
	
	POP R18
	POP R17
	POP R16
	RET 	

