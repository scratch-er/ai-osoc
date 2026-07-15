#ifndef __RTTHREAD_AM_STDLIB_H__
#define __RTTHREAD_AM_STDLIB_H__

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

void *malloc(size_t size);
void free(void *ptr);
void *calloc(size_t nmemb, size_t size);
void *realloc(void *ptr, size_t size);
int abs(int j);
int atoi(const char *nptr);
long strtol(const char *nptr, char **endptr, int base);
unsigned long strtoul(const char *nptr, char **endptr, int base);
void exit(int status);
int system(const char *command);

#ifdef __cplusplus
}
#endif

#endif
