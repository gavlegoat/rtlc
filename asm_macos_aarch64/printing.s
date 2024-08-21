	.data
newline: .byte 10

	.text
	.balign 4
	.global print_string
	.global print_int
	.global print_float
	.global print_newline

print_newline:
	; Print a newline to file descriptor X0
	adrp X1, newline@PAGE
	add X1, X1, newline@PAGEOFF
	mov X2, #1
	str LR, [SP, #-16]!
	bl _write
	ldr LR, [SP], #16
	ret

print_string:
	; Print a string pointed to by X1 to file descriptor X0
	str LR, [SP, #-16]!
	sub SP, SP, #32
print_string_loop:
	ldrb W3, [X1]
	cbz W3, print_string_end
	mov X2, #1
	str X1, [SP]
	str X0, [SP, #16]
	bl _write
	ldr X0, [SP, #16]
	ldr X1, [SP]
	add X1, X1, 1
	b print_string_loop
print_string_end:
	add SP, SP, #32
	ldr LR, [SP], #16
	ret

print_int:
	; Print the integer in X1 to file descriptor X0
	str LR, [SP, #-16]!
	cmp X1, #0
	bge print_int_main
	str X1, [SP, #-16]!
	mov X1, #45
	str X1, [SP, #-16]!
	mov X1, SP
	mov X2, #1
	str X0, [SP, #-16]!
	bl _write
	ldr X0, [SP], #16
	ldr X1, [SP, #16]
	neg X1, X1
	ldr LR, [SP, #32]
	add SP, SP, #48
	b print_int
print_int_main:
	cbnz X1, print_int_nonzero
	mov X1, #48
	str X1, [SP, #-16]!
	mov X1, SP
	mov X2, #1
	bl _write
	add SP, SP, #16
	b print_int_end
print_int_nonzero:
	mov X3, X1
	mov X4, #0
	mov X8, #10
print_int_build_stack:
	cbz X3, print_int_print
	udiv X5, X3, X8
	msub X6, X5, X8, X3
	add X6, X6, #48
	str X6, [SP, #-16]!
	add X4, X4, #1
	mov X3, X5
	b print_int_build_stack
print_int_print:
	cbz X4, print_int_end
	mov X1, SP
	mov X2, #1
	str X4, [SP, #-16]!
	str X0, [SP, #-16]!
	bl _write
	ldr X0, [SP], #16
	ldr X4, [SP], #16
	add SP, SP, #16
	sub X4, X4, #1
	b print_int_print
print_int_end:
	ldr LR, [SP], #16
	ret

print_float:
	; Print the float in S0 to file descriptor X0
	sub SP, SP, #48
	fcvtzs X1, S0
	str LR, [SP, #16]
	str X0, [SP, #32]
	str X1, [SP]
	bl print_int
	ldr X1, [SP]
	ldr X0, [SP, #32]
	scvtf S1, X1
	fsub S0, S0, S1
	mov X1, #46
	str X1, [SP]
	mov X1, SP
	mov X2, #1
	bl _write
	mov X1, #1000
	scvtf S1, X1
	fmul S0, S0, S1
	fcvtzs X1, S0
	cmp X1, #0
	bge print_float_finish
	neg X1, X1
print_float_finish:
	bl print_int
	ldr LR, [SP, #16]
	add SP, SP, #48
	ret
