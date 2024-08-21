	; Scene object
	;  0: camera position
	; 16: light position
	; 32: ambient factor
	; 36: specular factor
	; 40: specular power
	; 44: max reflections
	; 48: background color
	; 64: objects array pointer
	; 72: objects array length

	.text
	.balign 4
	.global scene_point_color

scene_point_color:
	; Get the color of the point stored in V0 given a scene at [X0]
	mov X1, #0
	ldr Q1, [X0]
	fsub V1.4S, V0.4S, V1.4S
	b ray_color

ray_color:
	; For a scene at [X0], get the color of a ray starting at V0 and
	; continuing along V1. X1 holds the number of reflections so far.
	sub SP, SP, #160
	str X0, [SP, #80]
	str X19, [SP, #64]
	str X20, [SP, #48]
	str X21, [SP, #144]
	str Q19, [SP, #32]
	str Q20, [SP, #16]
	str Q21, [SP, #96]
	str Q22, [SP, #112]
	str Q23, [SP, #128]
	str LR, [SP]
	mov X19, X0
	mov X20, X1
	mov V19.4S, V0.4S
	mov V20.4S, V1.4S
	bl nearest_intersection
	mov X21, X0    ; Store the shape pointer in X21
	fmov S2, #0
	fcmp S0, S2
	b.lt ray_color_background
	fmul V20.4S, V20.4S, V0.S[0]    ; V20.4S is the direction
	fadd V19.4S, V19.4S, V20.4S     ; V19.4S is the collision point
	mov V0.4S, V19.4S
	bl shape_color
	b ray_color_lighting
ray_color_background:
	ldr Q0, [X19, #48]
	b ray_color_end
ray_color_lighting:
	; Now V0.4S is the color of the shape
	mov V23.4S, V0.4S    ; Keep the shape color in V23.4S
	; Ambient
	ldr X1, [SP, #80]
	ldr S2, [X1, #32]   ; S2 is the scene's ambient factor
	mov V21.4S, V0.4S   ; V21.4S will be the final returned color
	fmul V21.4S, V21.4S, V2.S[0]    ; ret = color * ambient
	; Get the normal vector
	mov V0.4S, V19.4S
	mov X0, X21
	bl shape_normal
	bl normalize
	mov V22.4S, V0.4S   ; Store the normal vector in V22
	; TODO: Reflected
	; Check number of reflections
	ldr X1, [SP, #80]
	ldr W2, [X1, 44]
	cmp W20, W2       ; If refls >= max_refls
	b.ge ray_color_end_refl
	; Check reflectivity
	mov X0, X21
	bl shape_reflectivity
	ldr S1, =0x3b449ba6
	fcmp S0, S1       ; If reflectivity < 0.003
	b.lt ray_color_end_refl
	; op = normalize(-direction)
	mov V0.4S, V20.4S
	fneg V0.4S, V0.4S
	bl normalize
	; ref = op + 2 * (project(op, norm) - op)
	str Q0, [SP, #-16]!
	mov V1.4S, V22.4S
	bl project
	ldr Q1, [SP], #16
	fsub V0.4S, V0.4S, V1.4S
	fmov S2, #2
	fmul V0.4S, V0.4S, V2.S[0]
	fadd V1.4S, V0.4S, V1.4S
	; l_refl = (1 - amb) * refl * ray_color(sc, offset(col, ref), refls + 1)
	mov V0.4S, V19.4S
	bl offset_vector
	ldr X0, [SP, #80]
	mov X1, X20
	add X1, X1, #1
	bl ray_color
	str Q0, [SP, #-16]!
	mov X0, X21
	bl shape_reflectivity
	ldr Q1, [SP], #16
	fmul V0.4S, V1.4S, V0.S[0]
	ldr X1, [SP, #80]
	ldr S2, [X1, #32]   ; S2 is the scene's ambient factor
	fmov S1, #1
	fsub S2, S1, S2
	fmul V0.4S, V0.4S, V2.S[0]
	; lighting += l_refl
	fadd V21.4S, V21.4S, V0.4S
ray_color_end_refl:
	; Check if we're in shadow
	mov V0.4S, V19.4S
	ldr Q1, [X1, #16]
	fsub V1.4S, V1.4S, V0.4S   ; V1 points toward the light
	str Q1, [SP, #-16]!
	bl offset_vector
	mov X0, X19
	bl nearest_intersection
	ldr Q1, [SP], #16
	fmov S3, #0
	fcmp S0, S3
	b.lt ray_color_in_light
	mov V0.4S, V21.4S
	b ray_color_end
ray_color_in_light:
	; At this point V1 is still a vector pointing toward the light
	; and V19 is the collision point.
	; Diffuse
	mov V0.4S, V1.4S
	bl normalize
	str Q0, [SP, #-16]!
	mov V1.4S, V22.4S
	bl dot               ; S0 = dot_product(norm, light_dir)
	fmov S1, #0
	fcmp S0, S1
	fcsel S0, S1, S0, LT   ; S0 = max(0, dot_product(...))
	ldr X1, [SP, #96]
	ldr S2, [X1, #32]   ; S2 is the scene's ambient factor
	fmov S1, #1
	fsub S2, S1, S2
	fmul S2, S0, S2    ; S2 = S0 * (1 - ambient)
	mov X0, X21
	bl shape_reflectivity
	fsub S0, S1, S0   ; S0 = 1 - reflectivity
	fmul S0, S0, S2     ; S0 = max(...) * (1 - amb) * (1 - refl)
	fmul V1.4S, V23.4S, V0.S[0]
	fadd V21.4S, V21.4S, V1.4S
	; Specular
	; half = normalize(light_dir + (-dir).normalize)
	mov V0.4S, V20.4S
	fneg V0.4S, V0.4S
	bl normalize
	ldr Q1, [SP], #16
	fadd V0.4S, V0.4S, V1.4S
	bl normalize     ; Now V0.4S is half
	; l_spec = max(0, dot(half, norm)) ** spec_power * specular * white
	mov V1.4S, V22.4S
	bl dot
	fmov S1, #0
	fcmp S0, S1
	fcsel S0, S1, S0, LT   ; S0 = max(0, dot_product(half, norm))
	ldr X1, [SP, #80]
	ldr W0, [X1, #40]
	bl power               ; S0 = max(..) ** spec_power
	ldr X1, [SP, #80]
	ldr S1, [X1, #36]
	fmul S0, S1, S0
	; This constant should be 0x437f0000, but for some reason the assembler
	; doesn't like to let me load numbers that end with zero.
	ldr S2, =0x437f0001    ; S2 = 255.0
	fmul S0, S0, S2
	fmov W0, S0
	fmov S1, W0
	ins V1.S[1], W0
	ins V1.S[2], W0
	fadd V21.4S, V21.4S, V1.4S
	mov V0.4S, V21.4S
ray_color_end:
	ldr X19, [SP, #64]
	ldr X20, [SP, #48]
	ldr Q19, [SP, #32]
	ldr Q20, [SP, #16]
	ldr Q21, [SP, #96]
	ldr Q22, [SP, #112]
	ldr Q23, [SP, #128]
	ldr X21, [SP, #144]
	ldr LR, [SP]
	add SP, SP, #160
	ret

nearest_intersection:
	; Find the shape and time of nearest intersection. The scene is at [X0],
	; The ray is in V0 and V1. Return the shape pointer in X0 and the time
	; in S0.
	sub SP, SP, #112
	str X21, [SP, #16]
	str X19, [SP, #32]
	str X20, [SP, #48]
	str Q21, [SP, #64]
	str Q19, [SP, #80]
	str Q20, [SP, #96]
	str LR, [SP]
	ldr X21, [X0, #64]
	ldr W19, [X0, #72]
	mov V19.4S, V0.4S
	mov V20.4S, V1.4S
	fmov S21, #-1
nearest_intersection_loop:
	cbz W19, nearest_intersection_end
	mov X0, X21
	mov V0.4S, V19.4S
	mov V1.4S, V20.4S
	bl shape_collision
	str S0, [SP, #-16]!
	bl print_float
	bl print_newline
	ldr S0, [SP], #16
	fmov S2, #0
	fcmp S0, S2
	b.lt nearest_intersection_loop_footer
	fcmp S21, S2
	b.lt nearest_intersection_replace
	fcmp S0, S21
	b.lt nearest_intersection_replace
	b nearest_intersection_loop_footer
nearest_intersection_replace:
	fmov S21, S0
	mov X20, X21
nearest_intersection_loop_footer:
	add X21, X21, #16
	sub W19, W19, #1
	b nearest_intersection_loop
nearest_intersection_end:
	fmov S0, S21
	mov X0, X20
	ldr LR, [SP]
	ldr X21, [SP, #16]
	ldr X19, [SP, #32]
	ldr X20, [SP, #48]
	ldr Q21, [SP, #64]
	ldr Q19, [SP, #80]
	ldr Q20, [SP, #96]
	add SP, SP, #112
	ret

offset_vector:
	; Replace V0.4S by V0.4S + eps * V1.4S. Does not change _any_ other
	; registers.
	str Q2, [SP, #-16]!
	ldr S2, =0x358637bd   ; S2 = 0.000001
	fmul V2.4S, V1.4S, V2.S[0]
	fadd V0.4S, V0.4S, V2.4S
	ldr Q2, [SP], #16
	ret

power:
	; Raise the float S0 to the non-negative integer power W0
	fmov S1, #1
power_loop:
	cbz W0, power_end
	and W1, W0, #1
	cbz W1, power_even
	fmul S1, S1, S0
	sub W0, W0, #1
	b power_loop
power_even:
	fmul S0, S0, S0
	lsr W0, W0, 1
	b power_loop
power_end:
	fmov S0, S1
	ret
