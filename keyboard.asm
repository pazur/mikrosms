.include "C:\PROGRA~2\VMLAB\include\m16def.inc"

.EQU ADDR1 = 0b00100011 ;17
.EQU ADDR2 = 0b01010101 ;42

; IMPORTANT SETTING
.EQU I2C_ADDR_SELF =  ADDR1
.EQU I2C_ADDR_OTHER = 0

.DEF KEYBOARD_STATUS = r25
.EQU MULTIPLE_CLICK_BIT = 0
.EQU BUFFER_CHANGED_BIT = 1

.EQU KB_DDR = DDRA
.EQU KB_PORT = PORTA
.EQU KB_PIN = PINA

.EQU ROW0 = PA0
.EQU ROW1 = PA1
.EQU ROW2 = PA2
.EQU ROW3 = PA3
.EQU COL0 = PA4
.EQU COL1 = PA5
.EQU COL2 = PA6
.EQU COL3 = PA7

.CSEG
reset:
    rjmp start
.ORG INT2addr
    rjmp key_pressed
.ORG OVF0addr
    rjmp check_key_pressed
.ORG OC1Aaddr
    rjmp multiple_click_time_over
.org TWIaddr
    rjmp i2c_receive_int

.ORG 0x60
.DSEG
    BUFFER_WRITE_POSITION: .BYTE 1 ; where write
    BUFFER_READ_POSITION: .BYTE 1  ; where read
    BUFFER_SYNC_POSITION: .BYTE 1
    BUFFER: .BYTE 16               ; 2 nibbles - higher buttonnumber lower timesclicked

    RCV_BUFFER_LEN: .byte 1
    RCV_BUFFER: .byte 16

.CSEG
.include "wait.asm"
.include "lcd.asm"
.include "i2c.asm"

multiple_click_time_over:
    push r16
    in r16, sreg
    push r16

    cbr KEYBOARD_STATUS, 1 << MULTIPLE_CLICK_BIT
    ;stop timer1
    in r16, TCCR1B
    cbr r16, 1 << CS12 | 1 << CS11 | 1 << CS10
    out TCCR1B, r16

    pop r16
    out sreg, r16
    pop r16
    reti

check_key_pressed:
    push r16
    in r16, sreg
    push r16
    push r17
    push r18
    push r19
    push XH
    push XL

    ; turn off timer0
    ldi r16, 0
    out TCCR0, r16
    ; reset counter value
    ldi r16, 0
    out TCNT0, r16
    call keyboard_scan
    ;clear int2
    ldi r17, 1 << INTF2
    out GIFR, r17

    sbrc r16, 0 ; if set then keyboard_scan returned no key
    rjmp check_key_pressed_clean

    lds r18, BUFFER_WRITE_POSITION

    cpi r16, 3 << 4                    ; delete button
    brne check_send_button
        cpi r18, -1                    ; buffer was empty
        BRNE delete_letter_from_buffer
        jmp check_key_pressed_clean
        delete_letter_from_buffer:
        sbr KEYBOARD_STATUS, 1 << BUFFER_CHANGED_BIT
        cbr KEYBOARD_STATUS, 1 << MULTIPLE_CLICK_BIT
        dec r18
        sts BUFFER_WRITE_POSITION, r18
        lds r17, BUFFER_SYNC_POSITION
        cp r17, r18
        brge store_sync_position
        jmp check_key_pressed_clean
        store_sync_position:
        sts BUFFER_SYNC_POSITION, r18
        rjmp check_key_pressed_clean
    check_send_button:
    cpi r16, 15 << 4
    brne char_clicked
        cpi r18, -1
        BRNE run_send
        JMP check_key_pressed_clean
        run_send:
        CALL i2c_start
        LDI I2C_TEMP, I2C_ADDR_OTHER
        CALL i2c_send_addr
        ldi XH, high(BUFFER)
        ldi XL, low(BUFFER)
        send_i2c_byte:
          LD r16, X+
          mov r17, r16
          cbr r17, 0xF0
          swap r16
          cbr r16, 0xF0
          call get_button
          mov I2C_TEMP, r16
          CALL i2c_send_data
          dec r18
          cpi r18, -1
          brne send_i2c_byte
        CALL i2c_stop
        OUT TWCR, R2

        ldi r16, -1
        sts BUFFER_WRITE_POSITION, r16
        sts BUFFER_SYNC_POSITION, r16
        sbr KEYBOARD_STATUS, 1 << BUFFER_CHANGED_BIT
        cbr KEYBOARD_STATUS, 1 << MULTIPLE_CLICK_BIT
        rjmp check_key_pressed_clean


    char_clicked:
    ldi XH, high(BUFFER)               ;  X = BUFFER + BUFFER_WRITE_POSITION
    ldi XL, low(BUFFER)                ;
    cpi r18, -1                        ;  if BUFFER_WRITE_POSITION == -1 -> buffer empty
    breq new_click                     ;
    add XL, r18                        ;
    ldi r17, 0                         ;
    adc XH, r17                        ;
    ld r17, X+                         ;  r17 = BUFFER[BUFFER_WRITE_POSITION]
    sbrs KEYBOARD_STATUS, MULTIPLE_CLICK_BIT ;
    rjmp new_click                     ;
    mov r19, r17                       ;  r19 = BUFFER[BUFFER_WRITE_POSITION].buttonNumber
    cbr r19, 0b00001111                ;
    cp r19, r16                        ;
    brne new_click                     ;
    mov r18, r17
    cbr r18, 0b11110000
    ldi r17, 0
    swap r16
    call get_button      ;in r16 max clicks
    cp r18, r16
    brlo inc_click_count
    ldi r18, 0
    inc_click_count:
    inc r18
    add r18, r19                       ;
    st  -X, r18                        ;  save in last place
    rjmp after_click                   ;
    new_click:                         ;
        inc r18                        ;
        sbrs r18, 4                    ;
        rjmp save_new_click
        ldi r18, 15                    ;
        subi XL, 1
        sbci XH, 0
        save_new_click:
        sts BUFFER_WRITE_POSITION, r18 ;
        inc r16                        ;
        st X, r16

    after_click:
    ;reset timer1 value
    ldi r17,0
    ldi r16,0
    out TCNT1H,r17
    out TCNT1L,r16
    ;run TIMER1 <- if not timedout
    in r16, TCCR1B
    sbr r16, 1 << WGM12 | 1 << CS12 | 1 << CS10
    out TCCR1B, r16

    sbr KEYBOARD_STATUS, 1 << MULTIPLE_CLICK_BIT | 1 << BUFFER_CHANGED_BIT

    check_key_pressed_clean:
    pop XL
    pop XH
    pop r19
    pop r18
    pop r17
    pop r16
    out sreg, r16
    pop r16
    reti

key_pressed:
    push r16
    in r16, sreg   ;probably noy needed
    push r16       ;because ldi and out dont change SREG

    ldi r16, 1 << CS00 | 1 << CS02
    out TCCR0, r16

    pop r16
    out sreg, r16
    pop r16
    reti


keyboard_init: ;set rows as input, cols as output
    push r16
    ldi r16, 1 << COL0 | 1 << COL1 | 1 << COL2 | 1 << COL3
    out KB_DDR, r16
    ldi r16, 1 << ROW0 | 1 << ROW1 | 1 << ROW2 | 1 << ROW3
    out KB_PORT, r16
    pop r16
    ret

keyboard_scan: ; key in r16 ; uses r16, r17
    ; test_rows
    ldi r17, -58
    sbis KB_PIN, ROW0
    subi r17, -41
    sbis KB_PIN, ROW1
    subi r17, -45
    sbis KB_PIN, ROW2
    subi r17, -49
    sbis KB_PIN, ROW3
    subi r17, -53
    ; change rows <-> cols
    ldi r16, 1 << ROW0 | 1 << ROW1 | 1 << ROW2 | 1 << ROW3
    out KB_DDR, r16
    ldi r16, 1 << COL0 | 1 << COL1 | 1 << COL2 | 1 << COL3
    out KB_PORT, r16
    ; wait 1us
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    ; test cols
    sbis KB_PIN, COL0
    subi r17, -17
    sbis KB_PIN, COL1
    subi r17, -18
    sbis KB_PIN, COL2
    subi r17, -19
    sbis KB_PIN, COL3
    subi r17, -20
    ; change rows <-> cols //reset
    ldi r16, 1 << COL0 | 1 << COL1 | 1 << COL2 | 1 << COL3
    out KB_DDR, r16
    ldi r16, 1 << ROW0 | 1 << ROW1 | 1 << ROW2 | 1 << ROW3
    out KB_PORT, r16
    ; check if result correct
    ldi r16, 1
    cpi r17, 16
    brsh no_key_pressed
    swap r17
    mov r16, r17
  no_key_pressed:
    ret



i2c_receive_int:
	push r16
	in r16, SREG
	push r16
	
	CALL i2c_receive	
	
	POP R16
	OUT SREG, R16
	POP R16
	RETI



i2c_received_start:	
	LDI R16, 0
	STS RCV_BUFFER_LEN, R16
	RJMP i2c_receive_end

i2c_received_data:	
	LDS R16, RCV_BUFFER_LEN
	LDI XH, HIGH(RCV_BUFFER)
	LDI XL, LOW(RCV_BUFFER)
	ADD XL, R16
	LDI R17, 0
	ADC XH, R17	
	ST X, I2C_TEMP	
	INC R16
	STS RCV_BUFFER_LEN, R16
	RJMP i2c_receive_end

i2c_received_stop:		
	SER R16
	MOV R0, R16
	RJMP i2c_receive_end



start:
    ;initialize stack
    ldi r16, low(RAMEND)
    out spl, r16
    ldi r16, high(RAMEND)
    out sph, r16

    ;CONFIG I2C
	LDI R16, 32
	OUT TWBR, R16 ;by miec 100kHz
	LDI R16, I2C_ADDR_SELF
	OUT TWAR, R16
	LDI R16, 1 << TWEA | 1 << TWEN | 1 << TWIE ;| 1 << TWSTO
	OUT TWCR, R16
	MOV R2, R16
	CLR R0

    ;initialize others
    SBI DDRB, PB0
    SBI PORTB, PB0

    call LCD_INIT
    ldi LCD_TEMP, 0x40
    call lcd_goto

    call keyboard_init

    ; int2 on 1-->0
    in r16, MCUCSR
    cbr r16, 1 << ISC2
    out MCUCSR, r16
    ; enable int2 interruption
    in r16, GICR
    sbr r16, 1 << INT2
    out GICR, r16

    ; reset int2 interrupion
    ldi r16, 1 << INTF2
    out GIFR, r16

    ; timer0
    in r16, TIMSK
    sbr r16, 1 << TOIE0
    out TIMSK, r16

    ; timer 1
    in r16, TIMSK
    sbr r16, 1 << OCIE1A
    out TIMSK, r16
    ldi r16, LOW(3000)
    ldi r17, HIGH(3000)
    out OCR1AH, r17
    out OCR1AL, r16

    ;reset timer1 value
    ldi r17,0
    ldi r16,0
    out TCNT1H,r17
    out TCNT1L,r16

    ;stop timer1
    in r16, TCCR1B
    cbr r16, 1 << CS12 | 1 << CS11 | 1 << CS10
    out TCCR1B, r16

    ; buffer;
    ldi r16, -1
    sts BUFFER_WRITE_POSITION, r16
    sts BUFFER_READ_POSITION, r16
    sts BUFFER_SYNC_POSITION, r16
    ; click registers
    ldi KEYBOARD_STATUS, 0
    sei

forever:
     sbrs KEYBOARD_STATUS, BUFFER_CHANGED_BIT
     rjmp check_rcv
     cbr KEYBOARD_STATUS, 1 << BUFFER_CHANGED_BIT
     lds r24, BUFFER_READ_POSITION
     lds r23, BUFFER_WRITE_POSITION
     lds r22, BUFFER_SYNC_POSITION
     ldi XL, low(BUFFER)
     ldi XH, high(BUFFER)
     cp r22, r24
     breq write_buffer
     mov r16, r22
     inc r16
     subi r16, -0x40
     mov LCD_TEMP, r16
     call lcd_goto
     ldi LCD_TEMP, ' '
  clear_char:
     call lcd_d_send
     dec r24
     cp r22, r24
     brne clear_char
  set_position:
     mov LCD_TEMP, r16
     subi r16, -0x40
     call lcd_goto
     cpi r23, -1
     breq buffer_written_to_lcd
  write_buffer:
     cpi r24, -1
     breq write_letter
  write_current_letter:
     add XL, r24
     ldi r16, 0
     adc XH, r16
     ldi LCD_TEMP, 0b00010000
     call lcd_i_send
     dec r24
  write_letter:
     inc r24
     ld r16, X+
     mov r17, r16
     cbr r17, 0xF0 ;times
     swap r16
     cbr r16, 0xF0 ;key
     call get_button

     ;; go 1 letter back
     mov LCD_TEMP, r16
     call lcd_d_send
     cp r24, r23
     brlo write_letter
  buffer_written_to_lcd:
     sts BUFFER_READ_POSITION, r23
     cli
     lds r16, BUFFER_SYNC_POSITION
     cp r16, r22
     brne sync_changed
     sts BUFFER_SYNC_POSITION, r23
  sync_changed:
     sei

check_rcv:
	; display incoming data
	SBRS R0, 7
	RJMP forever
	
	CLR R0
	LDI lcd_temp, 0
	CALL lcd_goto
	
	LDS R17, RCV_BUFFER_LEN
	LDI R16, 0
	LDI XH, HIGH(RCV_BUFFER)
	LDI XL, LOW(RCV_BUFFER)
	RJMP loop_test
	
loop:		
	LD LCD_TEMP, X+
	CALL lcd_d_send	
	INC R16
loop_test:
	CP R16, R17
	BRLT loop

	LDI R17, 16
	LDI LCD_TEMP, ' '
	RJMP loop2_test
loop2:
	CALL lcd_d_send	
	INC R16
loop2_test:
	CP R16, R17
	BRLT loop2
	
	lds LCD_TEMP, BUFFER_READ_POSITION
	subi LCD_TEMP, -0x41
	call LCD_GOTO

   cbi PORTB, PB0
   WAITMS 10
   sbi PORTB, PB0
rjmp forever

get_button: ; r16 - key number, r17 times clicked (0 == number of signs)
            ; result in r16
    push ZL
    push ZH
    ldi ZL, low(keyboard_layout << 1)
    ldi ZH, high(keyboard_layout << 1)
    lsl r16
    add ZL, r16
    ldi r16, 0
    adc ZH, r16
    lpm r16, Z+
    lpm ZH, Z
    mov ZL, r16
    lsl ZL
    rol ZH
    ldi r16, 0
    add ZL, r17
    adc ZH, r16
    lpm r16, Z
    pop ZH
    pop ZL
    ret

button_0:
    .DB 5, ",.!?1"
button_1:
    .DB 4, "ABC2"
button_2:
    .DB 4, "DEF3"
button_3:

button_4:
    .DB 4, "GHI4"
button_5:
    .DB 4, "JKL5"
button_6:
    .DB 4, "MNO6"
button_7:
    .DB 1, ":"
button_8:
    .DB 5, "PQRS7"
button_9:
    .DB 4, "TUV8"
button_10:
    .DB 5, "WXYZ9"
button_11:
    .DB 1, ")"
button_12:
    .DB 5, "*+-()"
button_13:
    .DB 2, " 0"
button_14:
    .DB 1, "#"
button_15:

keyboard_layout:
    .DW button_0, button_1, button_2, button_3
    .DW button_4, button_5, button_6, button_7
    .DW button_8, button_9, button_10, button_11
    .DW button_12, button_13, button_14, button_15




