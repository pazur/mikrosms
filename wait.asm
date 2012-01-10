; ******************************************************
; Procedury opozniajace
; ******************************************************

.MACRO WAITUS 		;czeka @0+3/8 mikrosekund
	LDI R26, LOW(@0)
	LDI R27, HIGH(@0)
	SBIW R27:R26, 1
	CALL wait_us
.ENDMACRO
wait_us:
	SBIW R27:R26, 1
	ADIW R27:R26, 1 ;mozna by tu dac nopy
	SBIW R27:R26, 1
	BRNE wait_us
	RET

.MACRO WAITMS
	LDI R26, LOW(@0)
	LDI R27, HIGH(@0)
	RCALL wait_ms
.ENDMACRO
wait_ms:
	PUSH R27
	PUSH R26
	WAITUS 998
	POP R26
	POP R27
	SBIW R27:R26, 1
	ADIW R27:R26, 1 ;ew nopy
	SBIW R27:R26, 1
	BRNE wait_ms
	RET



