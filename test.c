#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/time.h>
extern void my_malloc_init(void);
extern void *my_malloc(size_t size);
extern void my_free(void *ptr);

#ifdef SILENT
#define printf(...)
#endif
#ifndef OPERATIONS
#define OPERATIONS 100000
#endif

#define BUFFER_SIZE (10 * 1024 * 1024) // 10 MB
#define CHUNK_SIZE 256


/* Struttura per rappresentare un blocco di memoria */
struct bin {
	unsigned char *ptr;
	size_t size;
};

/* Inizializza il contenuto della memoria */
void mem_init(unsigned char *ptr, size_t size) {
	size_t i, j;

	for (i = 0; i < size; ++i) {
		j = (size_t)ptr ^ i; // Combina indirizzo e indice
		ptr[i] = (unsigned char)(j ^ (j >> 8)); // Pattern basato su j
	}
}

/* Verifica il contenuto della memoria */
int mem_check(const unsigned char *ptr, size_t size) {
	size_t i, j;

	for (i = 0; i < size; ++i) {
		j = (size_t)ptr ^ i; // Ricrea il pattern basato su indirizzo e indice
		if (ptr[i] != (unsigned char)(j ^ (j >> 8))) // Confronta il valore memorizzato
			return 0; // Corruzione rilevata
	}
	return 1; // Memoria integra
}

/* Alloca un blocco di memoria */
void bin_alloc(struct bin *m, size_t size) {
	if (m->size > 0) {
		my_free(m->ptr);
	}
	m->ptr = my_malloc(size);
	if (!m->ptr) {
		printf("Out of memory! Requested size: %zu\n", size);
		exit(1);
	}
	m->size = size;
	mem_init(m->ptr, m->size);
}

/* Libera un blocco di memoria */
void bin_free(struct bin *m) {
	if (m->size == 0) return;
	if (!mem_check(m->ptr, m->size)) {
		printf("Memory corruption detected!\n");
		exit(1);
	}
	my_free(m->ptr);
	m->ptr = NULL;
	m->size = 0;
}

static void *ptrs[BUFFER_SIZE/CHUNK_SIZE] = {0};

void test_all_memory(void)
{
	printf("Allocating all memory...\n");
	for(size_t i = 0; i < BUFFER_SIZE/CHUNK_SIZE; i++) {
		ptrs[i] = my_malloc(CHUNK_SIZE);
		if(ptrs[i] == NULL) {
			printf("Out of memory! Requested size: %d\n", CHUNK_SIZE);
			exit(1);
		}
	}
	if(my_malloc(64) != NULL) {
		printf("Providing more memory than requested.\n");
		exit(1);
	}
	printf("Testing free...\n");
	my_free(ptrs[0]);
	if((ptrs[0] = my_malloc(CHUNK_SIZE)) == NULL) {
		printf("free() didn't free any memory\n");
		exit(1);
	}
	for(size_t i = 0; i < BUFFER_SIZE/CHUNK_SIZE; i++) {
		my_free(ptrs[i]);
	}
}


/* Test della malloc e della free */
int main(void) {
	struct timeval st,en;
	double elapsed;

	gettimeofday(&st,NULL);
	const int num_bins = 100;       // Numero di blocchi da testare
	const size_t max_size = 256;    // Dimensione massima di un blocco
	struct bin bins[num_bins];      // Array di blocchi
	int operations = OPERATIONS;    // Numero di operazioni da eseguire

	// Inizializza il gestore della memoria
	my_malloc_init();

	// Stress test delle specifiche dell'allocatore
	test_all_memory();
	gettimeofday(&en,NULL);
	// Inizializza i blocchi
	for (int i = 0; i < num_bins; ++i) {
		bins[i].ptr = NULL;
		bins[i].size = 0;
	}

	// Inizializza il generatore di numeri casuali
	srand((unsigned int)time(NULL));

	printf("Starting malloc/free test...\n");

	for (int op = 0; op < operations; ++op) {
		int idx = rand() % num_bins;
		int action = rand() % 10;

		if(bins[idx].ptr == NULL)
			action = 0;

		if (action < 8) {
			size_t size = (rand() % max_size) + 1; // Dimensione casuale tra 1 e max_size
			bin_alloc(&bins[idx], size);
			//printf("Allocated bin[%d]: %zu bytes\n", idx, size);
		} else { // Deallocazione
			//printf("Freeing bin[%d]\n", idx);
			bin_free(&bins[idx]);
		}
	}

	// Libera tutti i blocchi rimanenti
	for (int i = 0; i < num_bins; ++i) {
		bin_free(&bins[i]);
	}

	printf("All bins freed successfully.\n");
	
	
	double trascorso = (en.tv_usec-st.tv_usec)/1000;

	
	printf("Tempo passato in millisecondi: %2.f \n", trascorso);
	return 0;
}
