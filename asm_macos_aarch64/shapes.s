	; struct Sphere (52 bytes) {
	;    0: vector holding the color
	;   16: float holding the reflectivity
	;   32: vector holding the center point
	;   48: float holding the radius
	; }
	;
	; struct Plane (97 bytes) {
	;    0: vector holding the color
	;   16: float holding the reflectivity
	;   32: vector holding the point
	;   48: vector holding the normal vector
	;   64: (optional) vector holding the second color
	;   80: (optional) vector holding the orientation
	;   96: byte holding a boolean indicating the presence of a second color
	; }
	;
	; struct Shape (9 bytes) {
	;   0: pointer to a sphere or plane
	;   8: byte holding 0 for sphere or 1 for plane
	; }

	.text
	.balign 4
	.global shape_color
	.global shape_collision
	.global shape_normal
	.global shape_reflectivity

shape_reflectivity:
	ldr X0, [X0]
	ldr S0, [X0, #16]
	ret

shape_normal:
	; Get the normal vector to shape [X0] at point V0. Return in V0.
	ldrb W2, [X0, #8]
	ldr X0, [X0]
	cbz W2, shape_normal_sphere
	ldr Q0, [X0, #48]
	ret
shape_normal_sphere:
	ldr Q1, [X0, #32]
	fsub V0.4S, V0.4S, V1.4S
	ret

shape_color:
	; Get the color of shape [X0] at V0.
	ldrb W2, [X0, #8]
	ldr X0, [X0]
	cbnz W2, shape_color_plane
	ldr Q0, [X0]
	ret
shape_color_plane:
	; Check if the plane is checkerboard
	ldrb W2, [X0, #96]
	cbnz W2, shape_color_checked_plane
	ldr Q0, [X0]
	ret
shape_color_checked_plane:
	; In this case we are in a checkerboard plane
	sub SP, SP, #48
	str LR, [SP, #32]
	ldr Q2, [X0, #32]
	fsub V0.4S, V0.4S, V2.4S   ; v = pt - this.point
	ldr Q2, [X0, #80]
	str X0, [SP, #16]          ; SP[16] = the pointer to the plane
	str Q0, [SP]               ; SP[0] = v
	mov V1.4S, V2.4S
	bl project                 ; V0 = x = project(v, orientation)
	ldr Q1, [SP]
	fsub V2.4S, V1.4S, V0.4S   ; V2 = y = v - x
	str Q2, [SP]               ; SP[0] = y
	bl norm                    ; S0 = norm(x)
	ldr Q2, [SP]
	str S0, [SP]
	mov V0.4S, V2.4S
	bl norm
	ldr S1, [SP]               ; At this point S0 and S1 are norm(x) and norm(y)
	fcvtns X0, S0              ; Convert both to integers rounding to nearest
	fcvtns X1, S1
	add X0, X0, X1             ; X0 = int(x) + int(y)
	and X0, X0, #1             ; Check if X0 is odd
	ldr X1, [SP, #16]          ; Fix the stack
	ldr LR, [SP, #32]
	add SP, SP, #48
	cbz X0, shape_color_second_color
	ldr Q0, [X1]
	ret
shape_color_second_color:
	ldr Q0, [X1, #64]
	ret

shape_collision:
	; Get the time of first collision between the shape [X0] when the
	; incoming ray starts at V0 and proceeds along V1
	ldrb W1, [X0, #8]
	ldr X0, [X0]
	str LR, [SP, #-16]!
	cbz W1, shape_collision_sphere
	bl plane_collision
	b shape_collision_end
shape_collision_sphere:
	bl sphere_collision
shape_collision_end:
	ldr LR, [SP], #16
	ret

plane_collision:
	; Get the time of collision between the plane [X0] and the ray (V0, V1)
	sub SP, SP, #64
	str Q0, [SP, #16]
	str Q1, [SP, #32]
	str LR, [SP]
	ldr Q0, [X0, #48]    ; V2 = normal
	bl dot               ; S0 = angle = dot(normal, direction)
	str S0, [SP, #48]
	ldr W1, =100000
	scvtf S1, W1         ; S1 = 100000
	frecpe S1, S1        ; S1 = 1e-6
	fabs S0, S0
	fcmp S0, S1
	b.lt plane_collision_miss
	ldr Q0, [X0, #32]
	ldr Q1, [SP, #16]
	fsub V0.4S, V0.4S, V1.4S   ; V0 = this.point - start
	ldr Q1, [X0, #48]          ; V1 = normal
	bl dot
	ldr S8, [SP, #48]
	fdiv S0, S0, S8            ; S0 = t = dot(V0, V1) / angle
	b plane_collision_end
plane_collision_miss:
	fmov S0, #-1
plane_collision_end:
	ldr LR, [SP]
	add SP, SP, #64
	ret

sphere_collision:
	; Get the time of collision between the sphere [X0] and the ray (V0, V1)
	sub SP, SP, #80
	str Q0, [SP, #16]   ; SP[16] = start
	str Q1, [SP, #32]   ; SP[32] = dir
	str LR, [SP]        ; SP[0] = LR
	mov V0.4S, V1.4S
	bl dot              ; S0 = a = dot(dir, dir)
	ldr Q1, [SP, #16]
	str S0, [SP, #16]   ; SP[16] = a
	ldr Q0, [X0, #32]
	fsub V0.4S, V1.4S, V0.4S
	ldr Q1, [SP, #32]
	str Q0, [SP, #48]   ; SP[48] = v = start - center
	bl dot              ; S0 = dot(dir, v)
	fmov S1, #2
	fmul S0, S0, S1     ; S0 = b = 2 * dot(dir, v)
	str S0, [SP, #64]   ; SP[64] = b
	ldr Q0, [SP, #48]
	mov V1.4S, V0.4S
	bl dot              ; S0 = dot(v, v)
	ldr S1, [X0, #48]
	fmul S1, S1, S1
	fsub S0, S0, S1     ; S0 = c = dot(v, v) - radius**2
	fmov S1, #4
	fmul S0, S0, S1
	ldr S1, [SP, #16]
	fmul S0, S0, S1
	ldr S1, [SP, #64]
	fmul S1, S1, S1
	fsub S0, S1, S0    ; S0 = discr = b**2 - 4*a*c
	fmov S1, #0
	fcmp S0, S1
	b.lt sphere_collision_miss
	fsqrt S0, S0
	ldr S2, [SP, #64]   ; S2 = b
	fneg S2, S2         ; S2 = -b
	ldr S3, [SP, #16]   ; S3 = a
	fmov S4, #2
	fmul S3, S3, S4     ; S3 = 2 * a
	fadd S1, S2, S0
	fsub S0, S2, S0
	fdiv S0, S0, S3    ; S0 = t1 = (-b + sqrt(discr)) / (2 * a)
	fdiv S1, S1, S3    ; S1 = t2 = (-b - sqrt(discr)) / (2 * a)
	fmov S2, #0
	fcmp S0, S2
	b.lt sphere_collision_t1_neg
	fcmp S1, S2
	b.lt sphere_collision_end
	fmin S0, S0, S1
	b sphere_collision_end
sphere_collision_t1_neg:
	fmov S0, S1
	b sphere_collision_end
sphere_collision_miss:
	fmov S0, #-1
sphere_collision_end:
	ldr LR, [SP], #80
	ret
