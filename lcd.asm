; ******************************************************
; Obsluga LCD
; ******************************************************

; LCD_DATA_PORT - port danych
; LCD_E_PORT - port linii wyzwalajacej E
; LCD_RS_PORT - port linii RS
; LCD_DATA_DDR - rejestr kierunku danych
; LCD_E_DDR - rejestr kierunku linii E
; LCD_RS_DDR - rejestr kierunku linii RS
; OE - numer bitu linii OE
; RS - numer bitu linii RS
; D4 - numer bitu linii D4
; D5 - numer bitu linii D5
; D6 - numer bitu linii D6
; D7 - numer bitu linii D7

.EQU LCD_DATA_PORT = PORTD
.EQU LCD_E_PORT =    PORTD
.EQU LCD_RS_PORT =   PORTD
.EQU LCD_DATA_DDR =   DDRD
.EQU LCD_E_DDR =      DDRD
.EQU LCD_RS_DDR =     DDRD
.EQU RS = PD0
.EQU E  = PD1
.EQU D4 = PD2
.EQU D5 = PD3
.EQU D6 = PD4
.EQU D7 = PD5
.DEF LCD_TEMP = R20

lcd_init:
SBI LCD_RS_DDR, RS   ;wyjscia
SBI LCD_E_DDR, E
SBI LCD_DATA_DDR, D4 ; 30
SBI LCD_DATA_DDR, D5
SBI LCD_DATA_DDR, D6
SBI LCD_DATA_DDR, D7

CBI LCD_RS_PORT, RS
CBI LCD_E_PORT, E
	LDI R26, 40
	LDI R27, 0
	RCALL wait_ms
SBI LCD_E_PORT, E
SBI LCD_DATA_PORT, D4
SBI LCD_DATA_PORT, D5
CBI LCD_DATA_PORT, D6
CBI LCD_DATA_PORT, D7
CBI LCD_E_PORT, E
	LDI R26, 5
	RCALL wait_ms

SBI LCD_E_PORT, E
NOP
CBI LCD_E_PORT, E
	LDI R26, 100
	LDI R27, 0
	RCALL wait_us

SBI LCD_E_PORT, E
NOP
CBI LCD_E_PORT, E
	RCALL wait_us

SBI LCD_E_PORT, E
CBI LCD_DATA_PORT, D4
CBI LCD_E_PORT, E
	LDI R26, 40
	RCALL wait_us

LDI LCD_TEMP, 0b00101000 ;konfiguracja wyswietlacza
CALL lcd_i_send
LDI LCD_TEMP, 0b00001100 ;wyswietlacz wlaczony, kursor, miganie
CALL lcd_i_send
LDI LCD_TEMP, 0b00000110 ;inkrementacja adresu, przesuwanie kursora
CALL lcd_i_send
LDI LCD_TEMP, 0b00000001 ;clean
CALL lcd_i_send
LDI R26, 2
LDI R27, 0
RCALL wait_ms
LDI LCD_TEMP, 0b00000010 ;go home
CALL lcd_i_send
LDI R26, 2
LDI R27, 0
RCALL wait_ms
RET

; transmisja polbajtu z LCD_TEMP
lcd_half_send:
	SBI LCD_E_PORT, E
	CBI LCD_DATA_PORT, D4
	CBI LCD_DATA_PORT, D5
	CBI LCD_DATA_PORT, D6
	CBI LCD_DATA_PORT, D7
	SBRC LCD_TEMP, 4
	SBI LCD_DATA_PORT, D4
	SBRC LCD_TEMP, 5
	SBI LCD_DATA_PORT, D5
	SBRC LCD_TEMP, 6
	SBI LCD_DATA_PORT, D6
	SBRC LCD_TEMP, 7
	SBI LCD_DATA_PORT, D7
	CBI LCD_E_PORT, E
	RET

lcd_send:
   PUSH R26
   PUSH R27
	RCALL lcd_half_send
	SWAP LCD_TEMP
	RCALL lcd_half_send
	SWAP LCD_TEMP
   LDI R26, 40
	LDI R27, 0
	RCALL wait_us
	POP R27
	POP R26
	RET

lcd_d_send:
	SBI LCD_RS_PORT, RS
	RCALL lcd_send
	RET

lcd_i_send:
	CBI LCD_RS_PORT, RS
	RCALL lcd_send
	RET

lcd_goto:
	SBR lcd_temp, 1 << 7
	RCALL lcd_i_send
	RET

lcd_number:
	PUSH R17
	PUSH R16
	MOV R16, lcd_temp
	CPI R16, 10
	BRLO lower
   RCALL div_10
   PUSH R16 ;odloz reszte
   MOV lcd_temp, R17
	RCALL lcd_number
   POP R16
lower:
	RCALL lcd_write_10
	POP R16
	POP R17
	RET

lcd_write_10:
	SUBI R16, -0x30
	MOV lcd_temp, R16	
	RCALL lcd_d_send
	RET

div_10: ; R16 = R16 mod 10, R17 = R16 div 10
	PUSH R18
	PUSH R19
	LDI R18, 160
	LDI R19, 16
	LDI R17, 0
cmp:	
	CP R16, R18
	BRLO next
   SUB R16, R18
   ADD R17, R19
   RJMP cmp
next:
	LSR R18
	LSR R19
	CPI R18, 10
	BRSH cmp	
	POP R19
	POP R18
	RET	



