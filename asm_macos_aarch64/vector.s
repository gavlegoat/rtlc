	; Throughout this file all vectors are 3-element vectors of single-
	; precision floats.

	.text
	.balign 4
	.global dot
	.global norm
	.global normalize
	.global project

dot:
	; dot product of V0.4S and V1.4S
	fmul V0.4S, V0.4S, V1.4S
	mov S1, V0.S[0]
	mov S2, V0.S[1]
	fadd S1, S1, S2
	mov S2, V0.S[2]
	fadd S1, S1, S2
	fmov S0, S1
	ret

norm:
	; L2 norm of V0.4S
	mov V1.4S, V0.4S      ; V1 = V0
	str LR, [SP, #-16]!
	bl dot                ; S0 = dot(V0, V1) = dot(V0, V0)
	ldr LR, [SP], #16
	fsqrt S0, S0          ; S0 = sqrt(S0)
	ret

normalize:
	; Normalize V0.4S
	sub SP, SP, #32
	str Q0, [SP, #16]
	str LR, [SP]
	bl norm
	fmov S1, S0
	ldr LR, [SP]
	ldr Q0, [SP, #16]
	add SP, SP, #32
	fmov S2, #1
	fdiv S1, S2, S1
	fmul V0.4S, V0.4S, V1.S[0]
	ret

project:
	; Project V0.4S onto V1.4S
	sub SP, SP, #64
	str Q0, [SP, #32]
	str Q1, [SP, #16]
	str LR, [SP]
	bl dot
	str S0, [SP, #48]
	ldr Q0, [SP, #16]
	mov V1.4S, V0.4S
	bl dot
	ldr S1, [SP, #48]
	fdiv S1, S1, S0
	ldr Q0, [SP, #16]
	fmul V0.4S, V0.4S, V1.S[0]
	ldr LR, [SP]
	add SP, SP, #64
	ret
