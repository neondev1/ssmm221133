# Hash table implementation, used in assembly-to-machine-language transpiler
# Supported hash table sizes are (will be) 257, 1023, 8191.
# The sizes are chosen for the following properties:
#  - 257 = 2^2^3 + 1 is a Fermat prime;
#  - 1023 = 2^10 - 1 = 3 * 11 * 31 is a Mersenne number with small factors;
#  - 8191 = 2^13 - 1 is a Mersenne prime.
# These properties make modulo computation relatively easy.

# Compute r0 mod 257 (r0 mod (2^8+1))
mod257:
	ld	$0x00ff00ff,	r2
	mov	r0,		r1
	and	r2,		r0
	shr	$0x08,		r1
	and	r2,		r1
	ld	$0x0fff0fff,	r2
	not	r1
	and	r2,		r1
	ld	$0x00010001,	r3
	add	r3,		r1
	add	r1,		r0
	and	r2,		r0
	mov	r0,		r1
	shr	$0x10,		r1
	add	r1,		r0
	ld	$0xfff,		r1
	and	r1,		r0
# TODO deal with negative numbers



# Compute r0 mod 1023 (r0 mod (2^10-1))
mod1023:
	ld	$0x3ff003ff,	r2
	mov	r0,		r1
	and	r2,		r0
	ld	$0x003003ff,	r2
	shr	$0x0a,		r1
	and	r2,		r1
	add	r1,		r0
	mov	r0,		r1
	shr	$0x14,		r1
	add	r1,		r0
	ld	$0xffff,	r1
	and	r1,		r0
	mov	r0,		r1
	ld	$0x3ff,		r2
	and	r2,		r0
	shr	$0x0a,		r1
	add	r1,		r0
	ld	0xfffffc02,	r1
	add	r0,		r1
	bgt	r1,		mod1023__sub
	j	(r6)
mod1023__sub:
	mov	r1,		r0
	dec	r0
	j	(r6)



# Compute r0 mod 8191 (r0 mod (2^13-1))
mod8191:
	ld	$0x1fff,	r1
	mov	r0,		r2
	and	r1,		r2
	shr	$0xd,		r0
	ld	$0x0007ffff,	r3
	and	r3,		r0
	mov	r0,		r3
	and	r1,		r3
	add	r3,		r2
	shr	$0xd,		r0
	mov	r0,		r3
	and	r1,		r3
	add	r3,		r2
	mov	r2,		r0
	and	r1,		r0
	shr	$0xd,		r2
	add	r2,		r0
	ld	$0xffffe002,	r1
	add	r0,		r1
	bgt	r1,		mod8191__sub
	j	(r6)
mod8191__sub:
	mov	r1,		r0
	dec	r0
	j	(r6)
