#ifndef __RTTHREAD_AM_STDIO_H__
#define __RTTHREAD_AM_STDIO_H__

#include <stddef.h>
#include <stdarg.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct __rt_am_file FILE;

#ifndef EOF
#define EOF (-1)
#endif

#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2

extern FILE *stdin;
extern FILE *stdout;
extern FILE *stderr;

int printf(const char *format, ...);
int sprintf(char *str, const char *format, ...);
int snprintf(char *str, size_t size, const char *format, ...);
int vsprintf(char *str, const char *format, va_list ap);
int vsnprintf(char *str, size_t size, const char *format, va_list ap);
int puts(const char *s);
int putchar(int c);
int getc(FILE *stream);
int ferror(FILE *stream);
int rename(const char *oldpath, const char *newpath);
int remove(const char *pathname);

#ifdef __cplusplus
}
#endif

#endif
