# SM213 machine code interpreter
# This module expects well-formed machine code (i.e. the output of sm2hex.s) as input.
# As such, it performs minimal error checking (notably skipping register validity checks).

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
	ld	(r0),		r0		# r0 = pc
	mov	r0,		r1
	shr	$0x1f,		r1		# r1 = high bit of pc (0 or 0b1...1)
	beq	r1,		safe		# if unset, no chance of overflow
	ld	$mem,		r1
	add	r0,		r1		# r1 = actual instruction address
	not	r1				# r1 = ~address
	bgt	r1,		safe		# if address high bit set, no overflow
	beq	r1,		safe
	halt					# if overflow, halt
safe:
	ld	$mem,		r1
	add	r0,		r1		# r1 = actual instruction address
	ld	$0x2,		r2
	and	r1,		r2		# r2 = address & 0b...10
	bgt	r2,		pad		# if not 4-byte-aligned, pad
	ld	(r1),		r2		# load instruction into upper 2 bytes of r2
	shr	$0x10,		r2		# extract upper 2 bytes
	inc	r0
	inc	r0
	br	fetched
pad:
	dec	r1
	dec	r1
	ld	(r1),		r2		# load instruction into lower 2 bytes of r2
	inca	r1
	ld	(r1),		r3		# load ins_op_ext as it is convenient here
	inc	r0
	inc	r0
fetched:
	ld	$0xffff,	r1
	and	r1,		r2		# clean up junk in upper 2 bytes of r2
	ld	$pc,		r1
	st	r0,		(r1)		# store pc

	mov	r2,		r1
	shr	$0xc,		r1		# r1 = opcode

	deca	r5
	deca	r5
	st	r2,		0x0(r5)
	st	r3,		0x4(r5)
	ld	$table,		r0
	gpc	$0x2,		r6
	j	*(r0,r2,4)			# call procedure for specific opcode
	inca	r5
	inca	r5

	ld	(r5),		r6
	inca	r5
	j	(r6)				# return, this will probably never happen



# Load the last 4 bytes of a 6-byte instruction
load_ext:




# 0d--vvvvvvvv			ld	$v,		rd
ld_imm:




# 1psd	(p=o>>2)		ld	o(rs),		rd
ld:




.pos	0x1f00
stack_bottom:
halt:
	halt			# for bad jumps
table:
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
regs:
	.long	0x00000000	# r0
	.long	0x00000000	# r1
	.long	0x00000000	# r2
	.long	0x00000000	# r3
	.long	0x00000000	# r4
	.long	0x00000000	# r5
	.long	0x00000000	# r6
	.long	0x00000000	# r7

.pos	0x2000
vmem:	.long	0x00000000
