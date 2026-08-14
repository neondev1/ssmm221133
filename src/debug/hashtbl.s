# Hash table implementation, used in assembly-to-machine-language transpiler
# Supported hash table sizes are (will be) 257, 1023, 8191.

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
	ld	$0xffffffe2,	r1
	add	r0,		r1
	bgt	r1,		mod8191__sub
	j	(r6)
mod8191__sub:
	mov	r1,		r0
	dec	r0
	j	(r6)
