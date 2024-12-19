.org 0x800

# Queste direttive sono utilizzate dal linker per esporre le funzioni al file test.c e consentire l'esecuzione del programma
.globl	my_malloc_init
.type	my_malloc_init, @function
.globl	my_free
.type	my_free, @function
.globl	my_malloc
.type	my_malloc, @function

# Questa direttiva rende lo stack non eseguibile
.section .note.GNU-stack,"",@progbits

.data
# Se necessario, definire qui nuove variabili necessarie a supportare la malloc
	last_index: .quad 0
	bitmap: .fill 20480, 1, 0
	sizemap: .fill 20480, 1, 0
	count: .quad 0
# Qui sotto viene definito il buffer memory_pool di 10 MB.

.comm	memory_pool, 10485760, 16

.text
my_malloc_init:
	xorq %r13, %r13
	movq $0, last_index(%rip)
	retq

my_malloc:
	# memory allocation
	pushq %rbp
	movq %rsp, %rbp
	subq $24, %rsp
	# cmp $40959, %r13
	# je .stop
	call get_size
	movq %rax, -0x18(%rbp)
	movq %rax, %rdi

	mov last_index(%rip), %r13
	cmp $40960, %r13
	jb .tail_malloc
	call find_block

	cmpq $0, %rax
	je .end_malloc
	
	jmp .update
	.tail_malloc:
		addq $1, last_index(%rip)
		movq %r13, %rax
		movq $256, %rcx
		mul %rcx
		lea memory_pool(%rip), %rcx
		add %rcx, %rax

	.update:
		movq -0x18(%rbp), %r13
		addq %r13, count(%rip)
		movq count(%rip), %r13
		movq %rax, -0x10(%rbp)
		movq %rax, %rdi
		movq -0x18(%rbp), %rsi
		call update_maps

		movq -0x10(%rbp), %rax
		
	.end_malloc:
		movq %rbp, %rsp
		popq %rbp

		retq

# Ha in input size in %rdi

find_block:
	pushq %rbp
	movq %rsp, %rbp
	subq $16, %rsp
	xorq %r15, %r15
	xorq %rcx, %rcx
	xorq %r8, %r8

	movq %rdi, -0x8(%rbp)
	lea bitmap(%rip), %r14

	movq $0, -0x10(%rbp)

	.block_loop:
		movb (%r14, %rcx, 1), %r8b
		xorq %r9, %r9   		# indice ciclo bit
		.bit_loop:
			movq %r8, %rdi
			movq %r9, %rsi

			pushq %rcx
			call get_bit
			popq %rcx

			cmpq $0, %rax
			je .aggiornamento
			movl $0, -0x10(%rbp)
			jmp .incremento

			.aggiornamento:
				addl $1, -0x10(%rbp)
				movq -0x8(%rbp), %rax
				cmpq %rax, -0x10(%rbp)
				jne .incremento
				.block_found:
					movq %rcx, %rax         # Calcolo l'indirizzo del blocco trovato
					movq $8, %rcx
					mul %rcx
					addq %r9, %rax
					addq $1, %rax
					subq -0x8(%rbp), %rax
					movq $64, %rcx
					mul %rcx
					lea memory_pool(%rip), %r12
					addq %r12, %rax
					jmp .fine_find


			.incremento:
				addq $1, %r9
				cmpq $8, %r9
				jne .bit_loop
				addq $1, %rcx
				cmpq $20480, %rcx
				je .mem_full
				jmp .block_loop
	.mem_full:
		movq $0, %rax		# memory full
	
	.fine_find:
		movq %rbp, %rsp
		popq %rbp
		retq


my_free:
	pushq %rbp
	movq %rsp, %rbp
	subq $32, %rsp
	
	movq $1, -0x10(%rbp)
	
	movq %rdi, -0x18(%rbp)

	call get_index

	movq %rax, -0x8(%rbp)		# byte
	movq %rdx, -0x20(%rbp)		# bit

	lea bitmap(%rip), %r14
	lea sizemap(%rip), %r15

	movq -0x8(%rbp), %rcx
	movq -0x20(%rbp), %r9

	.free_sizemap:
		xorq %r10, %r10
		
		.free_size:
			movb (%r15, %rcx, 1), %r10b
			movq %r10, %rdi
			movq %r9, %rsi

			pushq %rcx
			call get_bit
			popq %rcx

			cmpq $0, %rax
			je .fine_size

			pushq %rcx
			call reset_bit
			popq %rcx
			
			movb %al, (%r15, %rcx, 1)
			addq $1, -0x10(%rbp)
			addq $1, %r9
			cmpq $8, %r9
			jne .free_size
			xorq %r9, %r9
			addq $1, %rcx
			jmp .free_sizemap
	
	.fine_size:
	movq -0x10(%rbp), %r13
	subq %r13, count(%rip)
	cmpq $0, count(%rip)
	jne .banana
	movq $0, last_index(%rip)
	movq last_index(%rip), %r13
	.banana:
	movq -0x8(%rbp), %rcx
	movq -0x20(%rbp), %r9
	.free_bitmap:
		xorq %r10, %r10
		
		.free_bit:
			movb (%r14, %rcx, 1), %r10b
			movq %r10, %rdi
			movq %r9, %rsi

			pushq %rcx
			call reset_bit
			popq %rcx

			movb %al, (%r14, %rcx, 1)

			subq $1, -0x10(%rbp)
			cmpq $0, -0x10(%rbp)
			je .fine_free
			addq $1, %r9
			cmpq $8, %r9
			jne .free_bit
			xorq %r9, %r9
			addq $1, %rcx
			jmp .free_bitmap

	.fine_free:
		movq -0x8(%rbp), %rcx
		movq %rbp, %rsp
		popq %rbp

		retq


# in input %rdi indirizzo, %rsi numero blocchi(size)

update_maps:
	pushq %rbp
	movq %rsp, %rbp
	subq $18, %rsp
	

	movq %rdi, -0x18(%rbp)
	movq %rsi, -0x10(%rbp)
	push %rsi
	call get_index				# controllare se indirizzo giusto
	movq %rax, %rcx
	push %rcx
	movq %rdx, %r9				# bit di partenza in update_bit
	push %rdx

	lea bitmap(%rip), %r14
	lea sizemap(%rip), %r15

	.update_bitmap:
		xorq %r10, %r10
		movb (%r14, %rcx, 1), %r10b
		.bitmap_bit:
			
			movq %r10, %rdi
			movq %r9, %rsi
			pushq %rcx
			call set_bit
			pop %rcx
			movb %al, %r10b

			subq $1, -0x10(%rbp)
			cmpq $0, -0x10(%rbp)
			je .end_bitmap
			
			addq $1, %r9
			cmpq $8, %r9
			jne .bitmap_bit
			movb %r10b, (%r14, %rcx, 1)
			xorq %r9, %r9
			addq $1, %rcx
			jmp .update_bitmap

	.end_bitmap:
	movb %r10b, (%r14, %rcx, 1)
	pop %rdx
	pop %rcx
	pop %rsi
	subq $1, %rsi
	movq %rsi, -0x10(%rbp)
	cmpq $0, -0x10(%rbp)
	je .allocate_64
	movq %rdx, %r9
	.update_sizemap:
		xorq %r10, %r10
		movb (%r15, %rcx, 1), %r10b
		.sizemap_bit:
			
			movq %r10, %rdi
			movq %r9, %rsi

			push %rcx
			call set_bit
			pop %rcx

			movb %al, %r10b

			subq $1, -0x10(%rbp)
			cmpq $0, -0x10(%rbp)
			je .fine_funzione
			addq $1, %r9
			cmpq $8, %r9
			jne .sizemap_bit
			movb %r10b, (%r15, %rcx, 1)
			xorq %r9, %r9
			addq $1, %rcx
			jmp .update_sizemap

	.fine_funzione:
		movb %r10b, (%r15, %rcx, 1)
		.allocate_64:
			movq %rbp, %rsp
			popq %rbp

			retq


# Dato la size in input determina il numero di blocchi necessari
get_size:
	xorq %rax, %rax

	.check_64:
		cmpq $64, %rdi
		ja .check_128
		movl $1, %eax   
		jmp .endif
	.check_128:
		cmpq $128, %rdi
		ja .check_256
		movl $2, %eax	
		jmp .endif
	.check_256:
		movl $4, %eax	
	
	.endif:

		retq

# Divisione tra rax (spiazzamento da inizio memory_pool) e dimensione blocco bitmap
# in rax va l'indice di accesso alla bitmap e nel resto l'indice corrispondente 
# all'interno della singola cella

get_index: # input indirizzo; output %rax byte, %rdx bit
	
	lea memory_pool(%rip), %rdx
	subq %rdx, %rdi 
	xorq %rdx,%rdx
	movq %rdi, %rax
	movq $64, %rcx
	div %rcx
	movq $8, %rcx
	div %rcx

	retq

# Setta valore bit nelle mappe, dato un indirizzo e la size del blocco

reset_bit:
	pushq %rbp
	movq %rsp, %rbp
	xorq %rax, %rax
	sub  $0x1, %rsp
	
	movb $0b00000001, %al # Creazione maschera di bit per azzerare i-esimo bit
	movq $7, %rcx
	subl %esi, %ecx # 7 - i per ottenere indice nella parola binaria (numero posizioni da shiftare)
	shl %cl, %al
	
	movb %al, -0x1(%rbp)

	movb $0b11111111, %al
	sub -0x1(%rbp), %al		# Fine creazione maschera

	andb %dil, %al 	# And tra byte e maschera per resettare l'i-esimo
	
	movq %rbp, %rsp
	popq %rbp

	ret

# Prende in input un byte e l'indice di un bit interno al byte e restituisce il valore di quel bit
get_bit:
	xorq %rax, %rax
	movq $7, %rcx
	subb %sil, %cl # 7 - i per ottenere indice nella parola binaria (numero posizioni da shiftare)
	movb %dil, %al
	shr %cl, %al

	andb $1, %al

	ret

# Prende in input un byte e l'indice interno al byte e setta a 1 l'i-esimo bit
set_bit:
    movb $1, %al             # Carico la maschera 0b00000001
    movq $7, %rcx
    subq %rsi, %rcx          # Calcola 7 - indice del bit
    shl %cl, %al             # Sposto il bit nella posizione corretta
    orb %al, %dil            # Eseguo OR per settare il bit
    movb %dil, %al           # Ritorno il byte aggiornato
    ret
