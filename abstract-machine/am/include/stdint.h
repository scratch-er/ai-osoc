#ifndef __AM_STDINT_H__
#define __AM_STDINT_H__

typedef signed char int8_t;
typedef unsigned char uint8_t;
typedef signed short int16_t;
typedef unsigned short uint16_t;
typedef signed int int32_t;
typedef unsigned int uint32_t;
typedef signed long long int64_t;
typedef unsigned long long uint64_t;

#if __riscv_xlen == 64
typedef signed long intptr_t;
typedef unsigned long uintptr_t;
#else
typedef signed int intptr_t;
typedef unsigned int uintptr_t;
#endif

#endif
