wait:
	DEC R16
	BRNE wait
	RET

wait_10us_loop:
	LDI R16, 25
	CALL wait
	DEC R15
	BRNE wait_10us_loop
	RET	

wait_10us: ;waits 10us * R16
	PUSH R15
	MOV R15, R16
	CALL wait_10us_loop
	POP R15
	RET

wait_ms_loop:
	LDI R16, 100
	CALL wait_10us
	DEC R15
	BRNE wait_ms_loop
	RET

wait_ms: ; waits R16 ms
	PUSH R15
	MOV R15, R16
	CALL wait_ms_loop
	POP R15
	RET
