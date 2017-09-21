#include <stdlib.h>
#include <stdio.h>
#include <stddef.h>
#include <string.h>
#include <time.h>
#include <math.h>
#include <assert.h>

struct soo_memory_t {
    unsigned long number_of_blocks;
    int inicial_of_block;
    unsigned long size_of_each_block;
    unsigned long number_of_free_blocks;
    struct soo_memory_entry_t** global_memory;
    int global_memory_count;
    int global_memory_max;
    struct soo_memory_entry_t* next;
};

struct soo_memory_entry_t {
    int index;
    int next;
    unsigned char using;
    struct soo_memory_data_t* data;
};

struct soo_memory_data_t {
    struct soo_memory_entry_t* entry;
};

static struct soo_memory_entry_t* soo_memory_array_new(struct soo_memory_t* self) {
    struct soo_memory_entry_t* entry_array = (struct soo_memory_entry_t*) malloc(self->inicial_of_block * sizeof(struct soo_memory_entry_t));
    if (!entry_array) return 0;
    int initial = self->global_memory_count * self->inicial_of_block;
    struct soo_memory_entry_t* entry_item = entry_array;
    int n; for (n = 0 ; n < self->inicial_of_block ; n++) {
        entry_item->index = initial + n;
        entry_item->next = entry_item->index + 1;
        entry_item->using = 0;
        entry_item->data = (struct soo_memory_data_t*) malloc(sizeof(struct soo_memory_data_t) + self->size_of_each_block);
        if (!entry_item->data) {
            int m; for (m = 0 ; m < n ; m++) free((&entry_array[m])->data);
            free(entry_array);
            return 0;
        }
        entry_item->data->entry = entry_item;
        entry_item++;
    }
    return entry_array;
}

struct soo_memory_t* soo_memory_new(int numberOfBlocks, unsigned long sizeOfEachBlock) {
    struct soo_memory_t* self = (struct soo_memory_t*) malloc(sizeof(struct soo_memory_t));
    if (!self) return 0;
    self->inicial_of_block = numberOfBlocks;
    self->number_of_blocks = numberOfBlocks;
    self->size_of_each_block = sizeOfEachBlock;
    self->number_of_free_blocks = numberOfBlocks;
    self->global_memory_max = 0;
    self->global_memory_count = 0;
    struct soo_memory_entry_t* memory_array = soo_memory_array_new(self);
    if (!memory_array) {
        free(self);
        return 0;
    }
    self->global_memory = malloc(self->global_memory_max * sizeof(struct soo_memory_entry_t*));
    if (!self->global_memory) {
        free(memory_array);
        free(self);
        return 0;
    }
    self->global_memory_max = 1;
    self->global_memory_count = 1;
    self->global_memory[0] = memory_array;
    self->next = memory_array;
    return self;
}

void soo_memory_reset(struct soo_memory_t* self) {
    self->next = (struct soo_memory_entry_t*) self->global_memory;
    self->number_of_free_blocks = self->number_of_blocks;
}

void soo_memory_free(struct soo_memory_t* self) {
    int n; for (n = 0 ; n < self->global_memory_count ; n++) {
        struct soo_memory_entry_t* local_memory = self->global_memory[n];
        int m; for (m = 0 ; m < self->inicial_of_block ; m++) free((&local_memory[m])->data);
        free(local_memory);
    }
    free(self->global_memory);
    free(self);
}

void* soo_memory_alloc(struct soo_memory_t* self) {
    struct soo_memory_entry_t* next = self->next;
    if (--self->number_of_free_blocks) {
        int next_index = next->next;
        int global_index = next_index / self->inicial_of_block;
        struct soo_memory_entry_t* local_array = self->global_memory[global_index];
        int local_index = next_index - global_index * self->inicial_of_block;
        self->next = &local_array[local_index];
    } else {
        if (self->global_memory_count == self->global_memory_max) {
            struct soo_memory_entry_t** globalMemory = (struct soo_memory_entry_t**) realloc(self->global_memory, self->global_memory_max * 2 * sizeof(struct soo_memory_entry_t*));
            if (!globalMemory) return 0;
            self->global_memory = globalMemory;
            self->global_memory_max *= 2;
        }
        struct soo_memory_entry_t* memory_array = soo_memory_array_new(self);
        if (!memory_array) return 0;
        self->number_of_blocks += self->inicial_of_block;
        self->number_of_free_blocks += self->inicial_of_block;
        self->next = memory_array;
        self->global_memory[self->global_memory_count++] = memory_array;
    }
    next->using = 1;
    return next->data + 1;
}

void soo_memory_dealloc(struct soo_memory_t* self, void* data) {
    struct soo_memory_data_t* pdata = (struct soo_memory_data_t*) (((unsigned char*) data) - sizeof(struct soo_memory_data_t));
    struct soo_memory_entry_t* entry = pdata->entry;
    entry->using = 0;
    entry->next = self->next->index;
    self->next = entry;
    self->number_of_free_blocks++;
//    while (self->number_of_free_blocks >= self->inicial_of_block * 2) {
//        struct soo_memory_entry_t* local_array = self->global_memory[self->global_memory_count - 1];
//        int n; for (n = 0 ; n < self->inicial_of_block ; n++) {
//            struct soo_memory_entry_t* entry = &local_array[n];
//            if (entry->using) {
//                struct soo_memory_entry_t* next = self->next;
//                int next_index = next->next;
//                int global_index = next_index / self->inicial_of_block;
//                struct soo_memory_entry_t* local_array = self->global_memory[global_index];
//                int local_index = next_index - global_index * self->inicial_of_block;
//                self->next = &local_array[local_index];
//                next->using = 1;
//                memcpy(entry->data, next->data, sizeof(struct soo_memory_data_t));
//                free(next->data);
//                next->data = entry->data;
//            }
//        }
//    }
}

#define nmax 1024*16

int main(int argc, char** argv) {
    setbuf(stdout, 0);
    int n; for (n = 0 ; n < 0xFF ; n++) {
        {
            struct soo_memory_t* pool = soo_memory_new(4 + n, 4);
            
            void* a1 = soo_memory_alloc(pool);
            void* a2 = soo_memory_alloc(pool);
            void* a3 = soo_memory_alloc(pool);
            void* a4 = soo_memory_alloc(pool);
            
            void* a5 = soo_memory_alloc(pool);
            void* a6 = soo_memory_alloc(pool);
            void* a7 = soo_memory_alloc(pool);
            void* a8 = soo_memory_alloc(pool);
            
            void* a9 = soo_memory_alloc(pool);
            void* a10 = soo_memory_alloc(pool);
            void* a11 = soo_memory_alloc(pool);
            void* a12 = soo_memory_alloc(pool);
            
            void* a13 = soo_memory_alloc(pool);
            void* a14 = soo_memory_alloc(pool);
            void* a15 = soo_memory_alloc(pool);
            void* a16 = soo_memory_alloc(pool);
            
            void* a17 = soo_memory_alloc(pool);
            void* a18 = soo_memory_alloc(pool);
            void* a19 = soo_memory_alloc(pool);
            void* a20 = soo_memory_alloc(pool);
            
            void* a21 = soo_memory_alloc(pool);
            void* a22 = soo_memory_alloc(pool);
            void* a23 = soo_memory_alloc(pool);
            void* a24 = soo_memory_alloc(pool);
            
            void* a25 = soo_memory_alloc(pool);
            void* a26 = soo_memory_alloc(pool);
            void* a27 = soo_memory_alloc(pool);
            void* a28 = soo_memory_alloc(pool);
            
            void* a29 = soo_memory_alloc(pool);
            void* a30 = soo_memory_alloc(pool);
            void* a31 = soo_memory_alloc(pool);
            void* a32 = soo_memory_alloc(pool);
            
            void* a33 = soo_memory_alloc(pool);
            void* a34 = soo_memory_alloc(pool);
            void* a35 = soo_memory_alloc(pool);
            void* a36 = soo_memory_alloc(pool);
            
            soo_memory_dealloc(pool,a1);
            soo_memory_dealloc(pool,a2);
            soo_memory_dealloc(pool,a3);
            soo_memory_dealloc(pool,a4);
            
            soo_memory_dealloc(pool,a5);
            soo_memory_dealloc(pool,a6);
            soo_memory_dealloc(pool,a7);
            soo_memory_dealloc(pool,a8);
            
            soo_memory_dealloc(pool,a9);
            soo_memory_dealloc(pool,a10);
            soo_memory_dealloc(pool,a11);
            soo_memory_dealloc(pool,a12);
            
            soo_memory_dealloc(pool,a13);
            soo_memory_dealloc(pool,a14);
            soo_memory_dealloc(pool,a15);
            soo_memory_dealloc(pool,a16);
            
            soo_memory_dealloc(pool,a17);
            soo_memory_dealloc(pool,a18);
            soo_memory_dealloc(pool,a19);
            soo_memory_dealloc(pool,a20);
            
            soo_memory_dealloc(pool,a21);
            soo_memory_dealloc(pool,a22);
            soo_memory_dealloc(pool,a23);
            soo_memory_dealloc(pool,a24);
            
            soo_memory_dealloc(pool,a25);
            soo_memory_dealloc(pool,a26);
            soo_memory_dealloc(pool,a27);
            soo_memory_dealloc(pool,a28);
            
            soo_memory_dealloc(pool,a29);
            soo_memory_dealloc(pool,a30);
            soo_memory_dealloc(pool,a31);
            soo_memory_dealloc(pool,a32);
            
            soo_memory_dealloc(pool,a33);
            soo_memory_dealloc(pool,a34);
            soo_memory_dealloc(pool,a35);
            soo_memory_dealloc(pool,a36);
            
            soo_memory_free(pool);
        }
        {
            struct soo_memory_t* pool = soo_memory_new(4, 4);
            
            void* a1 = soo_memory_alloc(pool);
            void* a2 = soo_memory_alloc(pool);
            void* a3 = soo_memory_alloc(pool);
            void* a4 = soo_memory_alloc(pool);
            
            void* a5 = soo_memory_alloc(pool);
            void* a6 = soo_memory_alloc(pool);
            void* a7 = soo_memory_alloc(pool);
            
            assert(a1 != a2);
            assert(a1 != a3);
            assert(a1 != a4);
            assert(a1 != a5);
            assert(a1 != a6);
            assert(a1 != a7);
            assert(a2 != a3);
            assert(a2 != a4);
            assert(a2 != a5);
            assert(a2 != a6);
            assert(a2 != a7);
            assert(a3 != a4);
            assert(a3 != a5);
            assert(a3 != a6);
            assert(a3 != a7);
            assert(a4 != a5);
            assert(a4 != a6);
            assert(a4 != a7);
            assert(a5 != a6);
            assert(a5 != a7);
            assert(a6 != a7);
            
            soo_memory_dealloc(pool,a1);
            soo_memory_dealloc(pool,a2);
            soo_memory_dealloc(pool,a3);
            soo_memory_dealloc(pool,a4);
            
            soo_memory_dealloc(pool,a5);
            soo_memory_dealloc(pool,a6);
            soo_memory_dealloc(pool,a7);
            
            void* b7 = soo_memory_alloc(pool);
            void* b6 = soo_memory_alloc(pool);
            void* b5 = soo_memory_alloc(pool);
            void* b4 = soo_memory_alloc(pool);
            
            void* b3 = soo_memory_alloc(pool);
            void* b2 = soo_memory_alloc(pool);
            void* b1 = soo_memory_alloc(pool);
            
            assert(a7 == b7);
            assert(a6 == b6);
            assert(a5 == b5);
            assert(a4 == b4);
            
            assert(a3 == b3);
            assert(a2 == b2);
            assert(a1 == b1);
            
            soo_memory_free(pool);
        }
        {
            struct soo_memory_t* pool = soo_memory_new(4, 4);
            
            void* a1 = soo_memory_alloc(pool);
            void* a2 = soo_memory_alloc(pool);
            void* a3 = soo_memory_alloc(pool);
            
            soo_memory_dealloc(pool,a1);
            soo_memory_dealloc(pool,a2);
            soo_memory_dealloc(pool,a3);
            
            assert(a1 != a2);
            assert(a1 != a3);
            assert(a2 != a3);
            
            void* b3 = soo_memory_alloc(pool);
            void* b2 = soo_memory_alloc(pool);
            void* b1 = soo_memory_alloc(pool);
            
            assert(b1 != b2);
            assert(b1 != b3);
            assert(b2 != b3);
            
            soo_memory_free(pool);
        }
        {
            struct soo_memory_t* pool = soo_memory_new(4, 4);
            
            void* a1 = soo_memory_alloc(pool);
            void* a2 = soo_memory_alloc(pool);
            void* a3 = soo_memory_alloc(pool);
            
            soo_memory_dealloc(pool,a1);
            soo_memory_dealloc(pool,a3);
            
            void* a9 = soo_memory_alloc(pool);
            
            soo_memory_free(pool);
        }
        {
            struct soo_memory_t* pool = soo_memory_new(4, 4);
            
            void* a1 = soo_memory_alloc(pool);
            void* a2 = soo_memory_alloc(pool);
            void* a3 = soo_memory_alloc(pool);
            void* a4 = soo_memory_alloc(pool);
            
            void* a5 = soo_memory_alloc(pool);
            void* a6 = soo_memory_alloc(pool);
            void* a7 = soo_memory_alloc(pool);
            void* a8 = soo_memory_alloc(pool);
            
            soo_memory_dealloc(pool,a1);
            soo_memory_dealloc(pool,a2);
            soo_memory_dealloc(pool,a3);
            soo_memory_dealloc(pool,a4);
            
            soo_memory_dealloc(pool,a5);
            soo_memory_dealloc(pool,a6);
            soo_memory_dealloc(pool,a7);
            soo_memory_dealloc(pool,a8);
            
            void* a9 = soo_memory_alloc(pool);
            void* a10 = soo_memory_alloc(pool);
            void* a11 = soo_memory_alloc(pool);
            void* a12 = soo_memory_alloc(pool);
            
            void* a13 = soo_memory_alloc(pool);
            void* a14 = soo_memory_alloc(pool);
            void* a15 = soo_memory_alloc(pool);
            void* a16 = soo_memory_alloc(pool);
            
            soo_memory_dealloc(pool,a9);
            soo_memory_dealloc(pool,a10);
            soo_memory_dealloc(pool,a11);
            soo_memory_dealloc(pool,a12);
            
            soo_memory_free(pool);
        }
    }
    {
        int n, m;
        int* buf[nmax];
        int* bufaux[nmax];
        // Gera um array randomico
        int ran[nmax];
        for (n = 0 ; n < nmax ; n++) {
            ran[n] = n;
        }
        for (n = 0 ; n < nmax-1 ; n++) {
            int i = n+1 + (n == nmax-1 ? 0 : rand() % (nmax - n - 1));
            int aux = ran[i];
            ran[i] = ran[n];
            ran[n] = aux;
        }
        // Iniciando o pool de memoria
        struct soo_memory_t* pool = soo_memory_new(4, 4);
        for (n = 0 ; n < nmax ; n++) {
            buf[n] = (int*) soo_memory_alloc(pool);
            buf[n][0] = n;
        }
        for (n = 0 ; n < nmax ; n++) {
            for (m = n + 1; m < nmax ; m++) {
                assert(buf[n] != buf[m]);
            }
        }
        for (n = 0 ; n < nmax ; n++) {
            assert(buf[n][0] == n);
        }
        for (n = 0 ; n < nmax ; n++) {
            int i = ran[n];
            assert(buf[i][0] == i);
            soo_memory_dealloc(pool, buf[i]);
        }
        memcpy(bufaux, buf, nmax * sizeof(int*));
        for (n = 0 ; n < nmax ; n++) {
            buf[n] = soo_memory_alloc(pool);
            assert(buf[n] == bufaux[ran[nmax-n-1]]);
            buf[n][0] = n;
        }
        for (n = 0 ; n < nmax ; n++) {
            for (m = n + 1; m < nmax ; m++) {
                assert(buf[n] != buf[m]);
            }
        }
        soo_memory_free(pool);
    }
    //	if (0) {
    //		int n, m, p, max = 2 * 1024, nmax = 16*1024;
    //		void* buf[max];
    //		for (p = 1 ; p < 50 ; p++) {
    //			int size = pow(4, p);
    //			double leftTime, rightTime;
    //			{
    //				printf("Size: %d\n", size);
    //				struct soo_memory_t* pool = soo_memory_new(max, size);
    //				leftTime = clock();
    //				{
    //					for (n = 0 ; n < nmax ; n++) {
    //						for (m = 0 ; m < max ; m++) {
    //							buf[m] = soo_memory_alloc(pool);
    //						}
    //						for (m = 0 ; m < max ; m++) {
    //							soo_memory_dealloc(pool, buf[m]);
    //						}
    //						soo_memory_reset(pool);
    //					}
    //					leftTime = clock() - leftTime;
    //					soo_memory_free(pool);
    //					printf("Time: %0.3f\n", (float) leftTime / 1000 / 1000);
    //				}
    //			}
    //			{
    //				rightTime = clock();
    //				{
    //					for (n = 0 ; n < nmax ; n++) {
    //						for (m = 0 ; m < max ; m++) {
    //							buf[m] = malloc(size);
    //						}
    //						for (m = 0 ; m < max ; m++) {
    //							free(buf[m]);
    //						}
    //					}
    //					rightTime = clock() - rightTime;
    //					printf("Time: %0.3f\n", (float) rightTime / 1000 / 1000);
    //				}
    //				printf("Times: %0.1f\n", (float) (rightTime / leftTime));
    //			}
    //		}
    //	}
    printf("Finished\n");
    return 0;
}
