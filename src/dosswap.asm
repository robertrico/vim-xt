;
; dosswap.asm - swap Vim out to a file, run a program, swap Vim back in.
;
; For the 16-bit MS-DOS build (Open Watcom, large model).  Vim holds most
; of 640K, so a program started with :! or :make would get almost none.
; This stub must stay resident while the rest of Vim is on disk, so it
; lives in its own segment, linked first so it sits right after the PSP,
; and uses only its own code segment for data and stack.
;
; os_msdos.c fills xt_swap_param, then calls xt_swap_run().  The stub:
;   1. writes the main memory block above itself, then every extra DOS
;      block Vim owns (heap), to the swap file;
;   2. frees the extra blocks and shrinks the main block to the stub;
;   3. runs the program with DOS EXEC;
;   4. grows the main block back, allocates the extra blocks again (they
;      must come back at the same segments), reads everything back.
; A failure before step 2 leaves Vim untouched and returns an error code.
; A failure after it can't be undone: print a message and exit, the user
; recovers from Vim's own .swp file.
;
; 8086 instructions only.
;
		.8086

DOSSWAP_TEXT	segment para public 'CODE'
		assume	cs:DOSSWAP_TEXT, ds:DOSSWAP_TEXT, es:nothing, ss:nothing

MAXBLK		equ	16

; Assemble with -dXT_SWAP_TRACE to show the stage reached as a digit in the
; top right corner of a colour screen (debugging only).
TRACE		macro	stage
ifdef XT_SWAP_TRACE
		push	es
		push	ax
		mov	ax, 0B800h
		mov	es, ax
		mov	byte ptr es:[009Eh], stage
		mov	byte ptr es:[009Fh], 4Fh
		pop	ax
		pop	es
endif
		endm

; --- parameters, filled by os_msdos.c (keep in step with struct xt_swap)
		public	_xt_swap_param
_xt_swap_param	label	byte
p_psp		dw	0		; our PSP segment
p_keep		dw	0		; paragraphs of main block to keep
p_mainsize	dw	0		; paragraphs of main block now
p_nblk		dw	0		; number of extra blocks
p_blkseg	dw	MAXBLK dup (0)	; extra block segments (after MCB)
p_blksize	dw	MAXBLK dup (0)	; extra block sizes in paragraphs
p_result	dw	0		; out: child exit code (4Dh)
p_error		dw	0		; out: 0 ok, see ERR_* in os_msdos.c
p_swapname	db	80 dup (0)	; ASCIIZ swap file name
p_prog		db	80 dup (0)	; ASCIIZ program path
p_tail		db	128 dup (0)	; command tail: length, text, CR

; --- private data
save_ss		dw	0
save_sp		dw	0
handle		dw	0
io_func		db	0		; 3Fh read or 40h write
holder		dw	MAXBLK dup (0)	; placeholder blocks while swapping in

epb		dw	0		; EXEC: environment, 0 = copy ours
epb_tail	dw	offset p_tail, 0
epb_fcb1	dw	offset fcb, 0
epb_fcb2	dw	offset fcb, 0
fcb		db	0, 11 dup (' '), 25 dup (0)

msg_fatal	db	13, 10, 'Vim: could not swap back in after running a '
		db	'program.', 13, 10
		db	'Your changes are in the .swp file: recover with '
		db	'"vim -r file".', 13, 10, '$'

		even
stack		dw	256 dup (0)
stack_top	label	word

;
; int xt_swap_run(void) - Watcom register convention, far.  Returns
; p_error in AX.  Preserves all other registers.
;
		public	xt_swap_run_
xt_swap_run_	proc	far
		pushf
		push	bx
		push	cx
		push	dx
		push	si
		push	di
		push	bp
		push	ds
		push	es

		; Switch to our own stack: Vim's is about to be swapped out.
		mov	cs:save_ss, ss
		mov	cs:save_sp, sp
		mov	ax, cs
		cli
		mov	ss, ax
		mov	sp, offset stack_top
		sti
		mov	ds, ax
		mov	p_error, 0
		mov	epb_tail + 2, ax
		mov	epb_fcb1 + 2, ax
		mov	epb_fcb2 + 2, ax

		; 1. Create the swap file and write everything out.
		mov	ah, 3Ch
		xor	cx, cx
		mov	dx, offset p_swapname
		int	21h
		jnc	created
		mov	p_error, 1		; ERR_CREATE
		jmp	done
created:	TRACE	'1'
		mov	handle, ax
		mov	io_func, 40h
		call	io_all
		jnc	written
		mov	bx, handle		; disk full or write error:
		mov	ah, 3Eh			; nothing is lost yet
		int	21h
		mov	dx, offset p_swapname
		mov	ah, 41h
		int	21h
		mov	p_error, 2		; ERR_WRITE
		jmp	done
written:	TRACE	'2'
		mov	bx, handle
		mov	ah, 3Eh
		int	21h

		; 2. Give the memory back to DOS.
		xor	si, si
free_loop:	mov	ax, si
		shr	ax, 1
		cmp	ax, p_nblk
		jae	free_done
		mov	es, p_blkseg[si]
		mov	ah, 49h
		int	21h
		add	si, 2
		jmp	free_loop
free_done:	mov	es, p_psp
		mov	bx, p_keep
		mov	ah, 4Ah
		int	21h

		TRACE	'3'
		; 3. Run the program.
		push	ds
		pop	es
		mov	bx, offset epb
		mov	dx, offset p_prog
		mov	ax, 4B00h
		int	21h
		mov	bx, cs			; DOS 2 doesn't keep SS:SP
		cli
		mov	ss, bx
		mov	sp, offset stack_top
		sti
		mov	ds, bx
		TRACE	'4'
		jc	exec_failed
		mov	ah, 4Dh
		int	21h
		mov	p_result, ax
		jmp	swap_in
exec_failed:	mov	p_result, ax		; DOS error code
		mov	p_error, 3		; ERR_EXEC

		; 4. Take the memory back, at the same places, and read it in.
swap_in:	mov	es, p_psp
		mov	bx, p_mainsize
		mov	ah, 4Ah
		int	21h
		jc	fatal
		TRACE	'5'
		; First fit may hand out a free gap below where a block was.
		; Hold such gaps with placeholder blocks and try again.
		xor	si, si
		xor	di, di			; DI = placeholders * 2
alloc_loop:	mov	ax, si
		shr	ax, 1
		cmp	ax, p_nblk
		jae	alloc_done
alloc_try:	mov	bx, p_blksize[si]
		mov	ah, 48h
		int	21h
		jc	fatal
		cmp	ax, p_blkseg[si]
		je	alloc_next
		ja	fatal			; past it: the spot is taken
		cmp	di, MAXBLK * 2
		jae	fatal
		mov	holder[di], ax
		add	di, 2
		jmp	alloc_try
alloc_next:	add	si, 2
		jmp	alloc_loop
alloc_done:	or	di, di
		jz	read_back
		sub	di, 2
		mov	es, holder[di]
		mov	ah, 49h
		int	21h
		jmp	alloc_done
read_back:	TRACE	'6'
		mov	ax, 3D00h
		mov	dx, offset p_swapname
		int	21h
		jc	fatal
		mov	handle, ax
		mov	io_func, 3Fh
		call	io_all
		jc	fatal
		TRACE	'7'
		mov	bx, handle
		mov	ah, 3Eh
		int	21h
		mov	dx, offset p_swapname
		mov	ah, 41h
		int	21h

done:		TRACE	'8'
		cli
		mov	ss, cs:save_ss
		mov	sp, cs:save_sp
		sti
		mov	ax, cs:p_error
		pop	es
		pop	ds
		pop	bp
		pop	di
		pop	si
		pop	dx
		pop	cx
		pop	bx
		popf
		ret

fatal:		mov	dx, offset msg_fatal
		mov	ah, 09h
		int	21h
		mov	ax, 4CFFh
		int	21h
xt_swap_run_	endp

;
; io_all: read or write (io_func) the swapped part of the main block, then
; every extra block, through "handle".  CF set on error or short count.
;
io_all		proc	near
		mov	ax, p_psp
		add	ax, p_keep
		mov	bx, p_mainsize
		sub	bx, p_keep
		call	io_span
		jc	io_ret
		xor	si, si
io_loop:	mov	ax, si
		shr	ax, 1
		cmp	ax, p_nblk
		jae	io_ok
		mov	ax, p_blkseg[si]
		mov	bx, p_blksize[si]
		push	si
		call	io_span
		pop	si
		jc	io_ret
		add	si, 2
		jmp	io_loop
io_ok:		clc
io_ret:		ret
io_all		endp

;
; io_span: read or write BX paragraphs starting at segment AX, in chunks
; of at most 32K.  CF set on error or short count.
;
io_span		proc	near
		mov	bp, ax			; BP = segment
		mov	si, bx			; SI = paragraphs left
span_loop:	or	si, si
		jz	span_ok
		mov	di, si			; DI = paragraphs this time
		cmp	di, 0800h
		jbe	span_1
		mov	di, 0800h
span_1:		mov	cx, di			; CX = bytes (<= 8000h)
		shl	cx, 1
		shl	cx, 1
		shl	cx, 1
		shl	cx, 1
		mov	bx, handle
		mov	ah, io_func
		push	ds
		mov	ds, bp
		xor	dx, dx
		int	21h
		pop	ds
		jc	span_ret
		cmp	ax, cx
		jne	span_bad
		add	bp, di
		sub	si, di
		jmp	span_loop
span_bad:	stc
		ret
span_ok:	clc
span_ret:	ret
io_span		endp

; End of what has to stay resident.
		public	_xt_swap_end
_xt_swap_end	label	byte

DOSSWAP_TEXT	ends
		end
