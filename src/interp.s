# SM213 machine code interpreter

.pos	0x0100
start:
	ld	$stack_bottom,	r5
	inca	r5
	gpc	$0x6,		r6
	j	main
	halt

main:
	deca	r5
	st	r6,		(r5)

	ld	$vmem,		r3
	ld	$pc,		r4
	ld	$op,		r7
loop:
	ld	(r4),		r0		# r0 = pc
	mov	r0,		r1
	shr	$0x1f,		r1		# r1 = high bit of pc (0 or 0b1...1)
	beq	r1,		safe		# if unset, no chance of overflow
	add	r3,		r0		# r0 = actual instruction address
	mov	r0,		r1
	not	r1
	inc	r1				# r1 = -address
	bgt	r1,		safe		# if address high bit set, no overflow
	halt					# if overflow, halt
safe:
	ld	$0x2,		r1
	and	r0,		r1		# r1 = r0 & 0b...10
	bgt	r1,		pad		# if not 4-byte-aligned, pad
	ld	(r0),		r1		# load instruction into upper 2 bytes of r0
	shr	$0x10,		r1		# extract upper 2 bytes
	inc	r0
	inc	r0
	br	fetched
pad:
	dec	r0
	dec	r0
	ld	(r0),		r1		# load instruction into lower 2 bytes of r0
	inca	r0
fetched:
	ld	$0xffff,	r2
	and	r2,		r1		# clean up junk in upper 2 bytes of r1
	st	r0,		(r4)		# store opcode/op_imm

	gpc	$0x6,		r6
	j	decode
	br	loop

	ld	(r5),		r6
	inca	r5
	j	(r6)				# return, this will probably never happen



# Decode and execute the instruction, given the opcode in r1
decode:
	deca	r5
	st	r6,		(r5)

	mov	r1,		r2
	shr	$0xc,		r2		# r2 = opcode
	shl	$0x3,		r2		# r2 = 8 * opcode
	ld	$break,		r6
	gpc	$0x4,		r0
	add	r2,		r0		# calculate jump destination
	j	(r0)

	j	ld_imm				# 0
	nop
	j	ld				# 1
	nop
	j	ld_i				# 2
	nop
	j	st				# 3
	nop
	j	st_i				# 4
	nop
	.long	0xf0f0f0f0			# 5
	.long	0xf0f0f0f0
	j	alu				# 6
	nop
	j	sh				# 7
	nop
	j	br				# 8
	nop
	j	beq				# 9
	nop
	j	bgt				# a
	nop
	j	jmp				# b
	nop
	j	j_ind				# c
	nop
	j	j_d				# d
	nop
	j	j_d_i				# e
	nop
	j	sys				# f

break:
	ld	(r5),		r6
	inca	r5
	j	(r6)



.pos	0x1fd0
stack_bottom:
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

