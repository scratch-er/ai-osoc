#include <am.h>
#include <klib.h>
#include <klib-macros.h>
#include <stdbool.h>

#if !defined(__ISA_NATIVE__) || defined(__NATIVE_USE_KLIB__)

static unsigned int random_seed;

static int digit_value(int c) {
  if (isdigit(c)) return c - '0';
  if (isupper(c)) return c - 'A' + 10;
  if (islower(c)) return c - 'a' + 10;
  return -1;
}

int rand(void) {
  if (random_seed == 0) {
    random_seed = 0x7a2d5eed;
  }
  unsigned int feedback = 0;
  feedback ^= (random_seed >> 31) | 1;
  feedback ^= (random_seed >> 21) | 1;
  feedback ^= (random_seed >> 1) | 1;
  feedback ^= (random_seed >> 0) | 1;
  random_seed >>= 1;
  random_seed |= feedback << 31;
  return (random_seed >> 1) % RAND_MAX;
}

void srand(unsigned int seed) {
  random_seed = seed;
}

int abs(int x) {
  return x < 0 ? -x : x;
}

int atoi(const char *nptr) {
  return strtol(nptr, NULL, 10);
}

long int atol(const char *nptr) {
  return strtol(nptr, NULL, 10);
}

long long int atoll(const char *nptr) {
  return strtoll(nptr, NULL, 10);
}

long int strtol(const char *str, char **endptr, int base) {
  size_t i = 0;
  bool negative = false;
  long int result = 0;

  if (base != 0 && (base < 2 || base > 36)) goto finish;
  while (isspace(str[i])) i++;
  if (str[i] == '+') {
    i++;
  } else if (str[i] == '-') {
    negative = true;
    i++;
  }

  if (base == 0) {
    if (str[i] == '0') {
      i++;
      if (str[i] == 'x' || str[i] == 'X') {
        base = 16;
        i++;
      } else {
        base = 8;
      }
    } else {
      base = 10;
    }
  } else if (base == 16 && str[i] == '0') {
    i++;
    if (str[i] == 'x' || str[i] == 'X') i++;
  }

  while (true) {
    int digit = digit_value(str[i]);
    if (digit < 0 || digit >= base) break;
    result = result * base + digit;
    i++;
  }

finish:
  if (endptr != NULL) *endptr = (char *)str + i;
  return negative ? -result : result;
}

long long int strtoll(const char *str, char **endptr, int base) {
  size_t i = 0;
  bool negative = false;
  long long int result = 0;

  if (base != 0 && (base < 2 || base > 36)) goto finish;
  while (isspace(str[i])) i++;
  if (str[i] == '+') {
    i++;
  } else if (str[i] == '-') {
    negative = true;
    i++;
  }

  if (base == 0) {
    if (str[i] == '0') {
      i++;
      if (str[i] == 'x' || str[i] == 'X') {
        base = 16;
        i++;
      } else {
        base = 8;
      }
    } else {
      base = 10;
    }
  } else if (base == 16 && str[i] == '0') {
    i++;
    if (str[i] == 'x' || str[i] == 'X') i++;
  }

  while (true) {
    int digit = digit_value(str[i]);
    if (digit < 0 || digit >= base) break;
    result = result * base + digit;
    i++;
  }

finish:
  if (endptr != NULL) *endptr = (char *)str + i;
  return negative ? -result : result;
}

unsigned long int strtoul(const char *str, char **endptr, int base) {
  size_t i = 0;
  unsigned long int result = 0;

  if (base != 0 && (base < 2 || base > 36)) goto finish;
  while (isspace(str[i])) i++;
  if (str[i] == '+') i++;

  if (base == 0) {
    if (str[i] == '0') {
      i++;
      if (str[i] == 'x' || str[i] == 'X') {
        base = 16;
        i++;
      } else {
        base = 8;
      }
    } else {
      base = 10;
    }
  } else if (base == 16 && str[i] == '0') {
    i++;
    if (str[i] == 'x' || str[i] == 'X') i++;
  }

  while (true) {
    int digit = digit_value(str[i]);
    if (digit < 0 || digit >= base) break;
    result = result * base + digit;
    i++;
  }

finish:
  if (endptr != NULL) *endptr = (char *)str + i;
  return result;
}

unsigned long long int strtoull(const char *str, char **endptr, int base) {
  size_t i = 0;
  unsigned long long int result = 0;

  if (base != 0 && (base < 2 || base > 36)) goto finish;
  while (isspace(str[i])) i++;
  if (str[i] == '+') i++;

  if (base == 0) {
    if (str[i] == '0') {
      i++;
      if (str[i] == 'x' || str[i] == 'X') {
        base = 16;
        i++;
      } else {
        base = 8;
      }
    } else {
      base = 10;
    }
  } else if (base == 16 && str[i] == '0') {
    i++;
    if (str[i] == 'x' || str[i] == 'X') i++;
  }

  while (true) {
    int digit = digit_value(str[i]);
    if (digit < 0 || digit >= base) break;
    result = result * base + digit;
    i++;
  }

finish:
  if (endptr != NULL) *endptr = (char *)str + i;
  return result;
}

void *malloc(size_t size) {
#if defined(__ISA_NATIVE__) && defined(__NATIVE_USE_KLIB__)
  return NULL;
#else
  static char *ptr = NULL;
  if (ptr == NULL) ptr = (char *)heap.end;
  size = ROUNDUP(size, sizeof(uintptr_t));
  if (ptr - size < (char *)heap.start) return NULL;
  ptr -= size;
  return ptr;
#endif
}

void free(void *ptr) {
}

void exit(int code) {
  halt(code);
  while (1);
}

void abort(void) {
  halt(-1);
  while (1);
}

#endif
