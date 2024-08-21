	.data

file_header:
	.byte 80, 54, 10                       ; P6\n
	.byte 53, 49, 50, 32, 53, 49, 50, 10   ; 512 512\n
	.byte 50, 53, 53, 10                   ; 255\n
	.byte 0                                ; (terminator)

sphere1:
	.single 255.0, 0.0, 0.0      ; color (plus one unused)
	.fill 1, 4                   ; unused
	.single 0.7                  ; reflectivity
	.fill 3, 4                   ; unused
	.single 0.25, 0.45, 0.4      ; center (plus one unused)
	.fill 1, 4                   ; unused
	.single 0.4                  ; radius

sphere2:
	.single 0.0, 255.0, 0.0      ; color (plus one unused)
	.fill 1, 4                   ; unused
	.single 0.7                  ; reflectivity
	.fill 3, 4                   ; unused
	.single 1.0, 1.0, 0.25       ; center (plus one unused)
	.fill 1, 4                   ; unused
	.single 0.25                 ; radius

sphere3:
	.single 0.0, 0.0, 255.0      ; color (plus one unused)
	.fill 1, 4                   ; unused
	.single 0.7                  ; reflectivity
	.fill 3, 4                   ; unused
	.single 0.8, 0.3, 0.15       ; center (plus one unused)
	.fill 1, 4                   ; unused
	.single 0.15                 ; radius

plane:
	.single 0.0, 0.0, 0.0         ; color
	.fill 1, 4                    ; unused
	.single 0.0                   ; reflectivity
	.fill 3, 4                    ; unused
	.single 0.0, 0.0, 0.0         ; point
	.fill 1, 4                    ; unused
	.single 0.0, 0.0, 1.0         ; normal
	.fill 1, 4                    ; unused
	.single 255.0, 255.0, 255.0   ; second color
	.fill 1, 4                    ; unused
	.single 0.0, 1.0, 0.0         ; orientation
	.fill 1, 4                    ; unused
	.byte 1                       ; is checkerboard

scene:
	.single 0.5, -1.0, 0.5        ; camera
	.fill 1, 4                    ; unused
	.single 0.0, -0.5, 1.0        ; light
	.fill 1, 4                    ; unused
	.single 0.2                   ; ambient
	.single 0.5                   ; specular
	.byte 8, 0, 0, 0              ; specular power (little-endian)
	.byte 6, 0, 0, 0              ; max reflections (little-endian)
	.single 135.0, 206.0, 235.0   ; background color
	.fill 1, 4
	.fill 1, 8                    ; objects array pointer
	.fill 1, 4                    ; objects array length

random_state:
	.fill 4      ; State of a PRNG

	.text
	.balign 4
	.global _main

_main:
	mov X2, #2
	cmp X0, X2       ; Throw an error if an argument is not provided
	b.eq skip_exit
	mov X0, #1
	ret
skip_exit:
	str LR, [SP, #-16]!
	ldr X0, [X1, #8]
	; Open the output file
	mov X1, #0x201        ; O_CREAT | O_WRONLY   =   0x200 | 0x1
	mov X2, #0666         ; read/write permissions for all.
	str X2, [SP, #-16]!   ; Permissions argument is optional, push it on the stack
	bl _open
	add SP, SP, #16
	; Write the file header
	adrp X1, file_header@PAGE
	add X1, X1, file_header@PAGEOFF
	str X0, [SP, #-16]!
	bl print_string
	bl build_scene
	str X21, [SP, #-16]!
	str X22, [SP, #-16]!
	str X23, [SP, #-16]!
	str X19, [SP, #-16]!
	str X20, [SP, #-16]!
	mov X21, #0
	mov X22, #512
	mul X23, X22, X22
	mov X20, X0        ; Move scene address into X20
	mov X0, #0         ; Address -- zero to allocate new memory
	mov X1, X23        ; Amount of memory to write
	mov X2, #3
	mul X1, X1, X2
	mov X2, #0x3       ; PROT_READ | PROT_WRITE   ---   0x1 | 0x2
	mov X3, #0x1001    ; MAP_ANON | MAP_SHARED    ---   0x1000 | 0x1
	mov X4, #-1        ; fd -- -1 for no file
	mov X5, #0         ; offset -- unneeded for us
	bl _mmap
	mov X19, X0        ; Move array address into X19
main_loop:
	cmp X21, X23
	b.ge end_main_loop
	udiv X0, X21, X22       ; X0 = i / width
	msub X1, X0, X22, X21   ; X1 = i % width
	mov X10, #9
	mov W11, #0
	fmov S20, W11
	ins V20.S[1], W11
	ins V20.S[2], W11
antialias_loop:
	cbz X10, end_antialias_loop
	str X0, [SP, #-16]!
	str X1, [SP, #-16]!
	bl random_float
	str S0, [SP, #-16]!
	bl random_float
	ldr S1, [SP], #16
	ldr X1, [SP], #16
	ldr X0, [SP], #16
	scvtf S2, X0
	scvtf S3, X1
	fadd S0, S0, S2     ; S0 = (i / width) + rand()
	fadd S1, S1, S3     ; S1 = (i % width) + rand()
	scvtf S3, X22       ; Divide S0, S1 by width
	fdiv S0, S0, S3
	fdiv S1, S1, S3
	fmov S2, #1         ; S0 = 1 - S0
	fsub S0, S2, S0
	fmov S2, S0
	fmov S3, #0
	str X0, [SP, #-16]!
	fmov W0, S1
	mov V0.S[0], W0
	fmov W0, S3
	mov V0.S[1], W0
	fmov W0, S2
	mov V0.S[2], W0
	mov X0, X20
	str X1, [SP, #-16]!
	str X10, [SP, #-16]!
	bl scene_point_color
	ldr X10, [SP], #16
	ldr X1, [SP], #16
	ldr X0, [SP], #16
	fadd V20.4S, V20.4S, V0.4S
	sub X10, X10, #1
	b antialias_loop
end_antialias_loop:
	ldr S0, =0x3de38e39
	fmul V0.4S, V20.4S, V0.S[0]
	mov X1, X21
	mov X0, #3
	mul X1, X0, X1
	add X1, X19, X1
	mov S1, V0.S[0]
	bl fix_color
	strb W0, [X1]
	mov S1, V0.S[1]
	bl fix_color
	strb W0, [X1, #1]
	mov S1, V0.S[2]
	bl fix_color
	strb W0, [X1, #2]
	add X21, X21, #1
	b main_loop
end_main_loop:
	mov X1, X19          ; Get address of memory to write
	mov X2, X23
	mov X3, #3
	mul X2, X2, X3       ; Number of bytes to write
	ldr X20, [SP], #16
	ldr X19, [SP], #16
	ldr X23, [SP], #16
	ldr X22, [SP], #16
	ldr X21, [SP], #16
	ldr X0, [SP], #16    ; Restore the file descriptor
	bl _write            ; Write the actual results
	ldr LR, [SP], #16
	mov X0, #0
	ret

fix_color:
	; NOTE: This procedure does not respect normal calling conventions.
	; Take a float in S1 and convert it to an integer between 0 and 255.
	; This function does not modify X1.
	; Return the result in X0.
	fcvtns X0, S1
	cmp X0, #0
	mov X2, #0
	csel X0, X2, X0, LT
	cmp X0, #255
	mov X2, 255
	csel X0, X2, X0, GT
	ret

random_float:
	; Generate a random float in the range [0, 1) and place it in S0
	; This uses a simple linear congruential generator to get random
	; mantissa bits for a float.
	adrp X0, random_state@PAGE
	add X0, X0, random_state@PAGEOFF
	ldr W1, [X0]            ; Load the last random number
	ldr W2, =1664525        ; Compute X_{n+1} = (a X_n + c) mod 2^32
	ldr W3, =1013904223     ;  with a and c taken from Numerical Recipes
	mul W1, W1, W2
	add W1, W1, W3
	str W1, [X0]            ; Store X_{n+1} as the new random state
	fmov S0, #1             ; Store 1 in S0 to get the sign and exp bits
	fmov W0, S0             ; Copy bits into W0
	orr W0, W0, W1, LSR#9   ; Get the generated mantissa bits
	fmov S0, W0             ; Move the new float into S0
	fmov S1, #1             ; Now S0 is uniformly distributed in [1, 2)
	fsub S0, S0, S1         ; Subtract one to get the final result
	ret

build_scene:
	; Allocate space for the objects array in `scene` and fill it.
	; Places the address of the scene object in X0
	str LR, [SP, #-16]!
	mov X0, #0         ; Address -- zero to allocate new memory
	mov X1, #64        ; Amount of memory to write
	mov X2, #0x3       ; PROT_READ | PROT_WRITE   ---   0x1 | 0x2
	mov X3, #0x1001    ; MAP_ANON | MAP_SHARED    ---   0x1000 | 0x1
	mov X4, #-1        ; fd -- -1 for no file
	mov X5, #0         ; offset -- unneeded for us
	bl _mmap
	; Now X0 is the beginning of the array
	mov X2, #0
	adrp X1, sphere1@PAGE
	add X1, X1, sphere1@PAGEOFF
	str X1, [X0]
	str X2, [X0, #8]
	adrp X1, sphere2@PAGE
	add X1, X1, sphere2@PAGEOFF
	str X1, [X0, #16]
	str X2, [X0, #24]
	adrp X1, sphere3@PAGE
	add X1, X1, sphere3@PAGEOFF
	str X1, [X0, #32]
	str X2, [X0, #40]
	mov X2, #1
	adrp X1, plane@PAGE
	add X1, X1, plane@PAGEOFF
	str X1, [X0, #48]
	str X2, [X0, #56]
	adrp X1, scene@PAGE
	add X1, X1, scene@PAGEOFF
	str X0, [X1, #64]
	mov W0, #4
	str W0, [X1, #72]
	mov X0, X1
	ldr LR, [SP], #16
	ret
