# SM213 machine code interpreter
#
# This module expects well-formed machine code (i.e. the output of sm2hex.s) as input.
# As such, it performs minimal error checking (notably skipping register validity checks).
# As a consequence of this, running data sections may produce unexpected behaviour if they
# contain malformed machine code. Specifically, it may either halt or nop depending on the
# opcode of an instruction. This is an easy fix but I'm too lazy right now (low priority).
# If you're running a data section you've probably screwed up and/or are running malicious
# code anyway, so I don't really consider this a major concern.
#
# Still, very minimal bounds-checking measures are still in place, specifically ensuring
# no addresses can overflow and cause the interpreter itself to be overwritten in memory.
# Self-preservation instinct, basically :P
#


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
	ld	(r7),		r7
	mov	r7,		r0			# r0 = pc

	gpc	$0x6,		r6
	j	to_addr					# r0 = actual instruction address

	mov	r7,		r1			# r1 = pc
	ld	$0x2,		r2
	and	r1,		r2			# r2 = pc & 0b...10
	bgt	r2,		main__pad		# if not 4-byte-aligned, pad
	ld	(r0),		r2			# load instruction into upper 2 bytes of r2
	shr	$0x10,		r2			# extract upper 2 bytes
	inc	r1
	inc	r1
	br	main__fetched
main__pad:
	dec	r0
	dec	r0
	ld	0x0(r0),	r2			# load instruction into lower 2 bytes of r2
	ld	0x4(r0),	r3			# load ins_op_ext as it is convenient here
	ld	$op_ext,	r4
	st	r3,		(r4)			# store in a global for now
	inc	r1
	inc	r1
main__fetched:
	ld	$0xffff,	r0
	and	r0,		r2			# clean up junk in upper 2 bytes of r2
	ld	$pc,		r7
	st	r1,		(r7)			# store pc

	mov	r2,		r1
	shr	$0xc,		r1			# r1 = opcode

	deca	r5
	st	r2,		(r5)			# pass instruction on the stack
	ld	$op_table,	r0
	gpc	$0x2,		r6
	j	*(r0,r1,4)				# call procedure for specific opcode
	inca	r5

	br	main__loop

	ld	(r5),		r6
	inca	r5
	j	(r6)					# return, this will probably never happen



# Attempt to add $vmem to the supplied virtual address in r0 and return the sum in r0;
# halt if this results in an overflow
to_addr:
	mov	r0,		r1
	shr	$0x1f,		r1			# extend sign bit, discard other bits
	ld	$vmem,		r2
	add	r2,		r0
	beq	r1,		to_addr__safe		# if unset, no chance of overflow
	mov	r0,		r1
	not	r1					# invert address
	bgt	r1,		to_addr__safe		# if original high bit set, no overflow
	beq	r1,		to_addr__safe
	halt						# halt if overflow occurred
to_addr__safe:
	j	(r6)



# Get the last 3 nibbles of a 2-byte instruction and store the last two in op_1, op_2,
# given the full instruction as an argument on the stack; returns the first nibble read in r0
get_op:
	ld	(r5),		r0
	mov	r0,		r1
	mov	r0,		r2
	ld	$0xf,		r3
	shr	$0x8,		r0
	and	r3,		r0			# r0 = op_0
	shr	$0x4,		r1
	and	r3,		r1			# r1 = op_1
	and	r3,		r2			# r2 = op_2
	ld	$op_1,		r3
	st	r1,		(r3)			# store op_1
	ld	$op_2,		r3
	st	r2,		(r3)			# store op_2
	j	(r6)



# Get the second nibble and last byte of a 2-byte instruction and store the byte in op_imm,
# given the full instruction as an argument on the stack; returns the nibble in r0
get_op_imm:
	ld	(r5),		r0
	mov	r0,		r1
	ld	$0xff,		r2
	shr	$0x4,		r0
	and	r2,		r0			# op_0 in left 4 bits of r0
	shr	$0x4,		r0			# r0 = op_0
	and	r2,		r1			# r1 = op_imm
	ld	$op_imm,	r2
	st	r1,		(r2)			# store op_imm
	j	(r6)



# Get the last 4 bytes of a 6-byte instruction and store it in op_ext
get_op_ext:
	ld	$pc,		r7
	ld	(r7),		r4
	mov	r4,		r0			# r0 = pc
	ld	$0x2,		r2
	and	r0,		r2			# r2 = pc & 0b...10
	beq	r2,		get_op_ext__aligned	# if 4-byte-aligned, already stored

	gpc	$0x6,		r6
	j	to_addr					# r0 = actual address

	dec	r0
	dec	r0
	ld	0x0(r0),	r2
	shl	$0x10,		r2			# first 2 bytes
	ld	0x4(r0),	r3
	shr	$0x10,		r3
	ld	$0xffff,	r1
	and	r1,		r3			# next 2 bytes
	add	r3,		r2			# add instead of bitwise or is fine here
	ld	$op_ext,	r1
	st	r2,		(r1)			# store in op_ext
get_op_ext__aligned:
	inca	r4					# update pc
	st	r4,		(r7)
	j	(r6)



# Load immediate
# 0d--vvvvvvvv			ld	$v,		rd
ins_ld_imm:
	deca	r5
	st	r6,		(r5)

	gpc	$0x6,		r6
	j	get_op_ext

	ld	$op_ext,	r0
	ld	(r0),		r0
	ld	$regs,		r1
	ld	0x4(r5),	r2			# load instruction into r2
	shr	$0x8,		r2			# r2 = d
	st	r0,		(r1,r2,4)		# store ins_op_ext into virtual rd

	ld	(r5),		r6
	inca	r5
	j	(r6)



# Load base+offset
# 1psd	(p=o>>2)		ld	o(rs),		rd
ins_ld:
	deca	r5
	st	r6,		(r5)

	ld	0x4(r5),	r0

	deca	r5
	st	r0,		(r5)
	gpc	$0x6,		r6
	j	get_op
	inca	r5

	ld	$op_1,		r1
	ld	(r1),		r1			# r1 = s
	ld	$regs,		r7
	ld	(r7,r1,4),	r1			# r1 = virtual rs
	shl	$0x2,		r0			# r0 = p<<2 = o
	add	r1,		r0			# r0 = o + rs

	gpc	$0x6,		r6
	j	to_addr					# get actual location in memory

	ld	(r0),		r0			# load o(rs) into r0

	ld	$op_2,		r2
	ld	(r2),		r2			# r2 = d
	st	r0,		(r7,r2,4)		# store r0 into virtual rd

	ld	(r5),		r6
	inca	r5
	j	(r6)



# Load indexed
# 2sid				ld	(rs,ri,4),	rd
ins_ld_i:
	deca	r5
	st	r6,		(r5)

	ld	0x4(r5),	r0

	deca	r5
	st	r0,		(r5)
	gpc	$0x6,		r6
	j	get_op
	inca	r5

	ld	$regs,		r7
	ld	(r7,r0,4),	r0			# r0 = virtual rs
	ld	$op_1,		r1
	ld	(r1),		r1			# r1 = i
	ld	(r7,r1,4),	r1			# r1 = virtual ri
	shl	$0x2,		r1			# r1 = ri<<2 = ri*4
	add	r1,		r0			# add instead of using a load indexed instruction;

	gpc	$0x6,		r6
	j	to_addr					# this is so that we can perform memory bounds checking

	ld	(r0),		r0			# load (rs,ri,4) into r0

	ld	$op_2,		r2
	ld	(r2),		r2			# r2 = d
	st	r0,		(r7,r2,4)		# store r0 into virtual rd

	ld	(r5),		r6
	inca	r5
	j	(r6)



# Store base+offset
# 3spd 	(p=o>>2)		st	rs,		o(rd)
ins_st:
	deca	r5
	st	r6,		(r5)

	ld	0x4(r5),	r0

	deca	r5
	st	r0,		(r5)
	gpc	$0x6,		r6
	j	get_op
	inca	r5

	ld	$regs,		r7
	ld	(r7,r0,4),	r4			# r4 = virtual rs

	ld	$op_1,		r0
	ld	(r0),		r0			# r0 = p
	shl	$0x2,		r0			# r0 = p<<2 = o
	ld	$op_2,		r1
	ld	(r1),		r1			# r1 = d
	ld	(r7,r1,4),	r1			# r1 = virtual rd
	add	r1,		r0			# r0 = o + rd

	gpc	$0x6,		r6
	j	to_addr

	st	r4,		(r0)			# store r4 into o(rd)

	ld	(r5),		r6
	inca	r5
	j	(r6)



# Store indexed
# 4sdi				st	rs,		(rd,ri,4)
ins_st_i:
	deca	r5
	st	r6,		(r5)

	ld	0x4(r5),	r0

	deca	r5
	st	r0,		(r5)
	gpc	$0x6,		r6
	j	get_op
	inca	r5

	ld	$regs,		r7
	ld	(r7,r0,4),	r4			# r4 = virtual rs

	ld	$op_1,		r0
	ld	(r0),		r0			# r0 = d
	ld	(r7,r0,4),	r0			# r0 = virtual rd
	ld	$op_2,		r1
	ld	(r1),		r1			# r1 = i
	ld	(r7,r1,4),	r1			# r1 = virtual ri
	shl	$0x2,		r1			# r1 = i<<2 = i*4
	add	r1,		r0			# once again, add instead of directly using st

	gpc	$0x6,		r6
	j	to_addr					# so that we can perform memory bounds checking

	st	r4,		(r0)			# store r4 into (rd,ri,4)

	ld	(r5),		r6
	inca	r5
	j	(r6)



# ALU instructions (excluding shifts)
# 6.sd				...	rs,		rd
# 6.-d				...	rd
# 6Fpd	(p=o>>1)		gpc	$o,		rd
alu:
	deca	r5
	st	r6,		(r5)

	ld	0x4(r5),	r0

	deca	r5
	st	r0,		(r5)
	gpc	$0x6,		r6
	j	get_op
	inca	r5

	ld	$regs,		r7
	ld	$op_2,		r3
	ld	(r3),		r3			# r3 = d
	ld	(r7,r3,4),	r2			# r2 = virtual rd

	ld	$alu_table,	r4
	j	*(r4,r0,4)

alu__mov:
	ld	$op_1,		r1
	ld	(r1),		r1			# r1 = s
	ld	(r7,r1,4),	r1			# r1 = virtual rs
	mov	r1,		r2			# r2 = r1
	br	alu__end
alu__add:
	ld	$op_1,		r1
	ld	(r1),		r1			# r1 = s
	ld	(r7,r1,4),	r1			# r1 = virtual rs
	add	r1,		r2			# r2 += r1
	br	alu__end
alu__and:
	ld	$op_1,		r1
	ld	(r1),		r1			# r1 = s
	ld	(r7,r1,4),	r1			# r1 = virtual rs
	and	r1,		r2			# r2 &= r1
	br	alu__end
alu__inc:
	inc	r2					# r2++
	br	alu__end
alu__inca:
	inca	r2					# r2 += 4
	br	alu__end
alu__dec:
	dec	r2					# r2--
	br	alu__end
alu__deca:
	deca	r2
	br	alu__end				# r2 -= 4
alu__not:
	not	r2					# r2 = ~r2
	br	alu__end
alu__gpc:
	ld	$op_1,		r1
	ld	(r1),		r1			# r1 = p
	shl	$0x1,		r1			# r1 = p<<1 = o
	ld	$pc,		r2
	ld	(r2),		r2			# r2 = pc
	add	r1,		r2			# r2 = o + pc

alu__end:
	st	r2,		(r7,r3,4)		# store result into rd

	ld	(r5),		r6
	inca	r5
	j	(r6)



# Bit shift, arithmetic immediate
# 7dss	(v=|s|)			sh[lr]	$v,		rd
ins_sh:
	deca	r5
	st	r6,		(r5)

	ld	0x4(r5),	r0

	deca	r5
	st	r0,		(r5)
	gpc	$0x6,		r6
	j	get_op_imm
	inca	r5

	ld	$regs,		r7
	ld	(r7,r0,4),	r1			# r1 = virtual rd
	ld	$op_imm,	r2
	ld	(r2),		r2			# r2 = op_imm = s (1 byte)
	shl	$0x18,		r2
	shr	$0x18,		r2			# promote/sign extend r2
	ld	$0x60,		r3
	bgt	r2,		ins_sh__left

ins_sh__right:
	not	r2
	inc	r2					# r2 = -s = v
	and	r2,		r3			# r3 = r2 & 0b01100000
	beq	r3,		ins_sh__right_4
	shr	$0x20,		r1			# shifting by more than 32 bits
	br	ins_sh__end
ins_sh__right_4:
	shl	$0x1b,		r2			# shift by 3 bytes + 3 bits
	inc	r2
	bgt	r2,		ins_sh__right_3		# use bgt so that we don't have to extract single bits
	shr	$0x10,		r1
ins_sh__right_3:
	shl	$0x1,		r2
	bgt	r2,		ins_sh__right_2
	shr	$0x08,		r1
ins_sh__right_2:
	shl	$0x1,		r2
	bgt	r2,		ins_sh__right_1
	shr	$0x04,		r1
ins_sh__right_1:
	shl	$0x1,		r2
	bgt	r2,		ins_sh__right_0
	shr	$0x02,		r1
ins_sh__right_0:
	shl	$0x1,		r2
	bgt	r2,		ins_sh__end
	shr	$0x01,		r1
	br	ins_sh__end

ins_sh__left:						# (r2 = s = v already)
	and	r2,		r3			# r3 = r2 & 0b01100000
	beq	r3,		ins_sh__left_4
	shl	$0x20,		r1			# shifting by more than 32 bits
	br	ins_sh__end
ins_sh__left_4:
	shl	$0x1b,		r2			# shift by 3 bytes + 3 bits
	inc	r2
	bgt	r2,		ins_sh__left_3		# use bgt so that we don't have to extract single bits
	shl	$0x10,		r1
ins_sh__left_3:
	shl	$0x1,		r2
	bgt	r2,		ins_sh__left_2
	shl	$0x08,		r1
ins_sh__left_2:
	shl	$0x1,		r2
	bgt	r2,		ins_sh__left_1
	shl	$0x04,		r1
ins_sh__left_1:
	shl	$0x1,		r2
	bgt	r2,		ins_sh__left_0
	shl	$0x02,		r1
ins_sh__left_0:
	shl	$0x1,		r2
	bgt	r2,		ins_sh__end
	shl	$0x01,		r1
	br	ins_sh__end

ins_sh__end:
	st	r1,		(r7,r0,4)		# store result in rd

	ld	(r5),		r6
	inca	r5
	j	(r6)



# Branches by an offset given as an argument on the stack
branch:
	ld	(r5),		r0			# r0 = op_imm = p (1 byte)
	shl	$0x18,		r0
	shr	$0x17,		r0			# promote/sign extend r0; r0 = p<<1 = p*2
	ld	$pc,		r7
	ld	(r7),		r1			# r1 = pc
	add	r0,		r1			# r1 = pc + p*2 = a
	st	r1,		(r7)			# pc = a
	j	(r6)



# Branch, unconditional
# 8-pp	(a=pc+p*2)		br	a
ins_br:
	deca	r5
	st	r6,		(r5)

	ld	0x4(r5),	r0

	deca	r5
	st	r0,		(r5)
	gpc	$0x6,		r6
	j	get_op_imm
	inca	r5

	ld	$op_imm,	r0
	ld	(r0),		r0			# r0 = op_imm = p

	deca	r5
	st	r0,		(r5)			# pass p on the stack
	gpc	$0x6,		r6
	j	branch
	inca	r5

	ld	(r5),		r6
	inca	r5
	j	(r6)



# Branch if equal to zero
# 9rpp	(a=pc+p*2)		beq	rr,		a
ins_beq:
	deca	r5
	st	r6,		(r5)

	ld	0x4(r5),	r0

	deca	r5
	st	r0,		(r5)
	gpc	$0x6,		r6
	j	get_op_imm
	inca	r5

	ld	$regs,		r7
	ld	(r7,r0,4),	r0			# r0 = virtual rr
	beq	r0,		ins_beq__branch		# branch if rr == 0
	br	ins_beq__end

ins_beq__branch:
	ld	$op_imm,	r0
	ld	(r0),		r0			# r0 = op_imm = p

	deca	r5
	st	r0,		(r5)			# pass p on the stack
	gpc	$0x6,		r6
	j	branch
	inca	r5

ins_beq__end:
	ld	(r5),		r6
	inca	r5
	j	(r6)



# Branch if greater than zero
# Arpp	(a=pc+p*2)		bgt	rr,		a
ins_bgt:
	deca	r5
	st	r6,		(r5)

	ld	0x4(r5),	r0

	deca	r5
	st	r0,		(r5)
	gpc	$0x6,		r6
	j	get_op_imm
	inca	r5

	ld	$regs,		r7
	ld	(r7,r0,4),	r0			# r0 = virtual rr
	bgt	r0,		ins_bgt__branch		# branch if rr == 0
	br	ins_bgt__end

ins_bgt__branch:
	ld	$op_imm,	r0
	ld	(r0),		r0			# r0 = op_imm = p

	deca	r5
	st	r0,		(r5)			# pass p on the stack
	gpc	$0x6,		r6
	j	branch
	inca	r5

ins_bgt__end:
	ld	(r5),		r6
	inca	r5
	j	(r6)



# Jump, direct
# B---aaaaaaaaa			j	a
ins_jmp:
	deca	r5
	st	r6,		(r5)

	gpc	$0x6,		r6
	j	get_op_ext

	ld	$op_ext,	r0
	ld	(r0),		r0			# r0 = op_ext = a
	ld	$pc,		r7
	st	r0,		(r7)			# pc = a

	ld	(r5),		r6
	inca	r5
	j	(r6)



ins_jmp_ind:
	halt
ins_jmp_dbl:
	halt
ins_jmp_dbl_i:
	halt



# Special (halt, syscall, nop)
# F0--				halt
# F1nn				sys	$n
# FF--				nop
ins_sys:
	deca	r5
	st	r6,		(r5)

	ld	0x4(r5),	r0

	deca	r5
	st	r0,		(r5)
	gpc	$0x6,		r6
	j	get_op_imm
	inca	r5

	beq	r0,		ins_sys__halt		# op_0 == 0
	dec	r0
	beq	r0,		ins_sys__sys		# op_0 == 1
	inc	r0
	inc	r0
	shl	$0x1f,		r0			# r0 = (op_0 + 1) << 31
	beq	r0,		ins_sys__end		# op_0 == f
ins_sys__halt:
	halt						# halt instruction or bad machine code

ins_sys__sys:
	ld	$regs,		r7
	ld	$op_imm,	r1
	ld	(r1),		r1			# r0 = op_imm = n
	deca	r1
	bgt	r1,		bad			# if n > 4, not in jump table
	inca	r1
	ld	$sys_table,	r0
	j	*(r0,r1,4)

ins_sys__io:
	mov	r1,		r4
	ld	0x4(r7),	r0			# r0 = virtual r1 = buffer

	gpc	$0x6,		r6
	j	to_addr

	mov	r0,		r1			# r1 = actual address of buffer
	ld	0x0(r7),	r0			# r0 = virtual r0 = fd
	ld	0x8(r7),	r2			# r2 = virtual r2 = size
	beq	r4,		ins_sys__read		# if n == 0, read, otherwise write
ins_sys__write:
	sys	$0x1
	br	ins_sys__sys_end
ins_sys__read:
	sys	$0x0
	br	ins_sys__sys_end

ins_sys__exec:
	ld	0x0(r7),	r0			# r0 = virtual r0 = buffer

	gpc	$0x6,		r6
	j	to_addr					# r0 = actual address of buffer

	ld	0x4(r7),	r1			# r1 = virtual r1 = size
	sys	$0x2

ins_sys__sys_end:
	st	r0,		(r7)			# store syscall return value in virtual r0

ins_sys__end:
	ld	(r5),		r6
	inca	r5
	j	(r6)



.pos	0x1f00
stack_bottom:
	.long	0x00000000
bad:
	halt			# filler entry for bad jumps
	halt			# padding
op_table:
	.long	ins_ld_imm	# 0
	.long	ins_ld		# 1
	.long	ins_ld_i	# 2
	.long	ins_st		# 3
	.long	ins_st_i	# 4
	.long	bad		# 5 (unused, maybe use for xchg in the future)
	.long	alu		# 6
	.long	ins_sh		# 7
	.long	ins_br		# 8
	.long	ins_beq		# 9
	.long	ins_bgt		# a
	.long	ins_jmp		# b
	.long	ins_jmp_ind	# c
	.long	ins_jmp_dbl	# d
	.long	ins_jmp_dbl_i	# e
	.long	ins_sys		# f
alu_table:
	.long	alu__mov	# 0
	.long	alu__add	# 1
	.long	alu__and	# 2
	.long	alu__inc	# 3
	.long	alu__inca	# 4
	.long	alu__dec	# 5
	.long	alu__deca	# 6
	.long	alu__not	# 7
	.long	bad
	.long	bad
	.long	bad
	.long	bad
	.long	bad
	.long	bad
	.long	bad
	.long	alu__gpc	# f
sys_table:
	.long	ins_sys__io	# 0
	.long	ins_sys__io	# 1
	.long	ins_sys__exec	# 2
	.long	bad
	.long	bad

.pos	0x1fa0
pc:	.long	0x00000000
op_1:	.long	0x00000000
op_2:	.long	0x00000000
op_imm:	.long	0x00000000
op_ext:	.long	0x00000000

.pos	0x1fc0
regs:
	.long	0x00000000	# r0
	.long	0x00000000	# r1
	.long	0x00000000	# r2
	.long	0x00000000	# r3
	.long	0x00000000	# r4
	.long	0x00000000	# r5
	.long	0x00000000	# r6
	.long	0x00000000	# r7
	.long	0xffffffff	# o
	.long	0xffffffff	# v
	.long	0xffffffff	# e
	.long	0xffffffff	# r
	.long	0xffffffff	# f
	.long	0xffffffff	# l
	.long	0xffffffff	# o
	.long	0xffffffff	# w

.pos	0x2000
vmem:
	.long	0x00000000
	.long	0x00000000
	.long	0x00000000
	.long	0x00000000
	.long	0x00000000
	.long	0x00000000
	.long	0x00000000
	.long	0x00000000
