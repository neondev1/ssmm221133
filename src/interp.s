# SM213 machine code interpreter
# This module expects well-formed machine code (i.e. the output of sm2hex.s) as input.
# As such, it performs minimal error checking (notably skipping register validity checks).

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

main__loop:
	ld	$pc,		r7
	ld	(r7),		r0		# r0 = pc
	mov	r0,		r1
	shr	$0x1f,		r1		# r1 = high bit of pc (0 or 0b1...1)
	beq	r1,		safe		# if unset, no chance of overflow
	ld	$mem,		r1
	add	r0,		r1		# r1 = actual instruction address
	not	r1				# r1 = ~address
	bgt	r1,		safe		# if address high bit set, no overflow
	beq	r1,		safe
	halt					# if overflow, halt
main__safe:
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
main__pad:
	dec	r1
	dec	r1
	ld	(r1),		r2		# load instruction into lower 2 bytes of r2
	inca	r1
	ld	(r1),		r3		# load ins_op_ext as it is convenient here
	ld	$op_ext,	r4
	st	r3,		(r4)		# store in a global for now
	inc	r0
	inc	r0
main__fetched:
	ld	$0xffff,	r1
	and	r1,		r2		# clean up junk in upper 2 bytes of r2
	st	r0,		(r7)		# store pc

	mov	r2,		r1
	shr	$0xc,		r1		# r1 = opcode

	deca	r5
	st	r2,		(r5)		# pass instruction
	ld	$table,		r0
	gpc	$0x2,		r6
	j	*(r0,r2,4)			# call procedure for specific opcode
	inca	r5

	br	loop

	ld	(r5),		r6
	inca	r5
	j	(r6)				# return, this will probably never happen



# Load the last 4 bytes of a 6-byte instruction and return it in r0; increment pc
load_ext:
	ld	$pc,		r7
	ld	(r7),		r0
	ld	$0x2,		r2
	and	r0,		r2		# r2 = pc & 0b...10
	ld	$op_ext,	r3
	ld	(r3),		r3
	beq	r2,		aligned		# if 4-byte-aligned, already loaded
	ld	$mem,		r1
	add	r0,		r1		# r1 = instruction address
	dec	r1
	dec	r1
	ld	0x0(r1),	r3
	shl	$0x10,		r3		# first 2 bytes
	ld	0x4(r1),	r4
	shr	$0x10,		r4
	ld	$0xffff,	r2
	and	r2,		r4		# next 2 bytes
	add	r4,		r3		# add instead of bitwise or is fine here
load_ext__aligned:
	inca	r0				# update pc
	st	r0,		(r7)
	mov	r3,		r0		# return all 4 bytes
	j	(r6)



# Load immediate
# 0d--vvvvvvvv			ld	$v,		rd
ld_imm:
	deca	r5
	st	r6,		(r5)

	gpc	$0x6,		r6
	j	load_ext			# load ins_op_ext into r0

	ld	$regs,		r1
	ld	0x4(r5),	r2		# load instruction into r2
	shr	$0x8,		r2		# r2 = d (destination register #)
	st	r0,		(r1,r2,4)	# store ins_op_ext into rd

	ld	(r5),		r6
	inca	r5
	j	(r6)



# Load base+offset
# 1psd	(p=o>>2)		ld	o(rs),		rd
ld:
	ld	(r5),		r0		# load instruction into r0
	mov	r0,		r1
	mov	r0,		r2



# Load indexed
# 2sid				ld	(rs,ri,4),	rd
ld_i:



.pos	0x1f00
stack_bottom:
	.long	0x00000000
halt:
	halt			# for bad jumps
table:
	.long	ld_imm		# 0
	.long	ld		# 1
	.long	ld_i		# 2
	.long	st		# 3
	.long	st_i		# 4
	.long	halt		# 5 (unused, maybe use for xchg later)
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
