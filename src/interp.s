# SM213 machine code interpreter

# For all procedures, assume that r0-r4 will be clobbered

.pos	0x0100
start:
	ld	$stack_bottom,	r5		# DO NOT inca r5
	gpc	$0x6,		r6
	j	main
	halt



main:
	deca	r5
	st	r6,		(r5)

loop:
	ld	$pc,		r0
	ld	(r0),		r7		# r7 = pc
	mov	r7,		r1
	shr	$0x1f,		r1		# r1 = high bit of pc (0 or 0b1...1)
	beq	r1,		safe		# if unset, no chance of overflow
	ld	$mem,		r1
	add	r7,		r1		# r1 = actual instruction address
	mov	r1,		r2
	not	r2
	inc	r2				# r2 = -address
	bgt	r2,		safe		# if address high bit set, no overflow
	halt					# if overflow, halt
safe:
	ld	$0x2,		r2
	and	r1,		r2		# r2 = address & 0b...10
	bgt	r2,		pad		# if not 4-byte-aligned, pad
	ld	(r1),		r1		# load instruction into upper 2 bytes of r1
	shr	$0x10,		r1		# extract upper 2 bytes
	inc	r7
	inc	r7
	br	fetched
pad:
	dec	r1
	dec	r1
	ld	(r1),		r1		# load instruction into lower 2 bytes of r1
	inc	r7
	inc	r7
fetched:
	ld	$0xffff,	r2
	and	r2,		r1		# clean up junk in upper 2 bytes of r1
	ld	$pc,		r0
	st	r7,		(r0)		# store pc

	mov	r1,		r2
	shr	$0xc,		r2		# r2 = opcode
	ld	$jump_table,	r0
	gpc	$0x2,		r6
	j	*(r0,r2,4)

	ld	(r5),		r6
	inca	r5
	j	(r6)				# return, this will probably never happen



# 0d--vvvvvvvv			ld	$v,		rd
ld_imm:




# 1psd	(p=o>>2)		ld	o(rs),		rd
ld:




.pos	0x1f00
stack_bottom:
halt:
	halt			# for bad jumps
jump_table:
	.long	ld_imm		# 0
	.long	ld		# 1
	.long	ld_i		# 2
	.long	st		# 3
	.long	st_i		# 4
	.long	halt		# 5 (unused)
	.long	alu		# 6
	.long	sh		# 7
	.long	br		# 8
	.long	beq		# 9
	.long	bgt		# a
	.long	jmp		# b
	.long	j_ind		# c
	.long	j_dbl		# d
	.long	j_dbl_i		# e
	.long	sys		# f

.pos	0x1fd0
pc:	.long	0x00000000
op:	.long	0x00000000
op_ext:	.long	0x00000000

.pos	0x1fe0
r0:	.long	0x00000000
r1:	.long	0x00000000
r2:	.long	0x00000000
r3:	.long	0x00000000
r4:	.long	0x00000000
r5:	.long	0x00000000
r6:	.long	0x00000000
r7:	.long	0x00000000

.pos	0x2000
vmem:	.long	0x00000000
