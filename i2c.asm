; ******************************************************
; Obsluga I2C
; ******************************************************
.EQU MT_START = $08
.EQU MT_SLA_ACK = $18
.EQU MT_DATA_ACK = $28
.EQU SR_SLA_ACK = $60
.EQU SR_DATA_ACK = $80
.EQU SRG_SLA_ACK = $70
.EQU SRG_DATA_ACK = $90
.EQU SR_STOP = $A0

.DEF I2C_TEMP = R20

i2c_start:
	LDI r16, 1 << TWINT | 1 << TWEN | 1<<TWSTA
	OUT TWCR, r16
	RCALL i2c_wait
	IN r16, TWSR
	ANDI R16, 0xF8
	CPI R16, MT_START
	BRNE i2c_error
	RET

i2c_stop:
	LDI r16, 1 << TWINT | 1 << TWEN | 1<<TWSTO
	OUT TWCR, r16
i2c_stop_wait:
	IN r16, TWCR
	SBRC r16, TWSTO
	RJMP i2c_stop_wait	
	RET

i2c_send_addr:
	RCALL i2c_send
	CPI R16, MT_SLA_ACK
	BRNE i2c_error
	RET

i2c_send_data:
	RCALL i2c_send
	CPI R16, MT_DATA_ACK
	BRNE i2c_error
	RET

i2c_send:
	OUT TWDR, I2C_TEMP
	LDI r16, 1 << TWINT | 1 << TWEN
	OUT TWCR, r16
	RCALL i2c_wait
	IN R16, TWSR
	ANDI r16, 0xF8	
	RET

i2c_wait:
	IN r16, TWCR
	SBRS r16, TWINT
	RJMP i2c_wait
   RET

i2c_error:
	;handle error here
	MOV R3, R16
	LDI lcd_temp, $40
	CALL lcd_goto
	LDI lcd_temp, 'E'
	CALL lcd_d_send
	MOV lcd_temp, R3
	CALL lcd_number
	RET

i2c_receive:
	IN I2C_TEMP, TWDR
	IN r16, TWSR
	ANDI R16, 0xF8	
	CPI R16, SR_SLA_ACK
	BREQ r_sta
	CPI R16, SRG_SLA_ACK
	BREQ r_sta	
	CPI R16, SR_DATA_ACK
	BREQ r_dat
	CPI R16, SRG_DATA_ACK
	BREQ r_dat	
	CPI R16, SR_STOP
	BREQ r_sto
	;error - napraw
	IN R16, TWCR
	SBR R16, 1 << TWSTO
	OUT TWCR, R16
	

i2c_receive_end:	
	IN R16, TWCR
	SBR R16, 1 << TWINT
	OUT TWCR, R16
	RET

r_sta:
	JMP i2c_received_start
r_dat:
	JMP i2c_received_data
r_sto:
	JMP i2c_received_stop
