#ifndef __RTTHREAD_AM_WCHAR_H__
#define __RTTHREAD_AM_WCHAR_H__

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __cplusplus
typedef int wchar_t;
#endif

int wcwidth(wchar_t wc);
int wcswidth(const wchar_t *s, size_t n);

#ifdef __cplusplus
}
#endif

#endif
