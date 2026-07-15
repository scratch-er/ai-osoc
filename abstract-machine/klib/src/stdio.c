#include <am.h>
#include <klib.h>
#include <klib-macros.h>
#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdarg.h>

#if !defined(__ISA_NATIVE__) || defined(__NATIVE_USE_KLIB__)

typedef struct {
  char *dest;
  void (*putch_fn)(char ch);
  size_t count;
  size_t max_count;
} printf_state_t;

static void printf_backend(printf_state_t *state, const char *fmt, va_list ap);

int printf(const char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  printf_state_t state = {
    .dest = NULL,
    .putch_fn = putch,
    .count = 0,
    .max_count = (size_t)-1,
  };
  printf_backend(&state, fmt, ap);
  va_end(ap);
  return state.count;
}

int vsprintf(char *out, const char *fmt, va_list ap) {
  return vsnprintf(out, (size_t)-1, fmt, ap);
}

int sprintf(char *out, const char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  int ret = vsprintf(out, fmt, ap);
  va_end(ap);
  return ret;
}

int snprintf(char *out, size_t n, const char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  int ret = vsnprintf(out, n, fmt, ap);
  va_end(ap);
  return ret;
}

int vsnprintf(char *out, size_t n, const char *fmt, va_list ap) {
  printf_state_t state = {
    .dest = out,
    .putch_fn = NULL,
    .count = 0,
    .max_count = n == 0 ? 0 : n - 1,
  };
  printf_backend(&state, fmt, ap);
  if (n > 0) {
    out[state.count < n ? state.count : n - 1] = '\0';
  }
  return state.count;
}

static void printf_putch(printf_state_t *state, char ch) {
  if (state->count < state->max_count) {
    if (state->putch_fn != NULL) {
      state->putch_fn(ch);
    } else {
      state->dest[state->count] = ch;
    }
  }
  state->count++;
}

static void printf_pad(printf_state_t *state, char ch, size_t n) {
  for (size_t i = 0; i < n; i++) {
    printf_putch(state, ch);
  }
}

static void printf_char(printf_state_t *state, char ch, size_t width, bool left_justified) {
  if (!left_justified && width > 1) {
    printf_pad(state, ' ', width - 1);
  }
  printf_putch(state, ch);
  if (left_justified && width > 1) {
    printf_pad(state, ' ', width - 1);
  }
}

static void printf_string(printf_state_t *state, const char *str, size_t width, bool left_justified) {
  if (str == NULL) str = "(null)";
  size_t len = strlen(str);
  if (!left_justified && width > len) {
    printf_pad(state, ' ', width - len);
  }
  while (*str) {
    printf_putch(state, *str++);
  }
  if (left_justified && width > len) {
    printf_pad(state, ' ', width - len);
  }
}

static void printf_unsigned(printf_state_t *state, unsigned long long n, unsigned int base,
                            size_t width, bool left_justified, char padding, bool upper_case) {
  char buffer[32];
  unsigned int n_digits = 0;
  do {
    unsigned int rem = n % base;
    buffer[n_digits++] = rem < 10 ? rem + '0' : rem - 10 + (upper_case ? 'A' : 'a');
    n /= base;
  } while (n != 0);

  unsigned int digits = n_digits;
  if (!left_justified && width > digits) {
    printf_pad(state, padding, width - digits);
  }
  while (n_digits > 0) {
    printf_putch(state, buffer[--n_digits]);
  }
  if (left_justified && width > digits) {
    printf_pad(state, ' ', width - digits);
  }
}

static void printf_signed(printf_state_t *state, long long n, size_t width,
                          bool left_justified, char padding, char sign) {
  unsigned long long val;
  bool neg = n < 0;
  if (neg) {
    val = -(unsigned long long)n;
  } else {
    val = n;
  }

  if (neg || sign != '\0') {
    if (!left_justified && padding == ' ' && width > 0) {
      printf_pad(state, ' ', width - 1);
      width = 1;
    }
    printf_putch(state, neg ? '-' : sign);
    if (width > 0) width--;
  }
  printf_unsigned(state, val, 10, width, left_justified, padding, false);
}

static void printf_backend(printf_state_t *state, const char *fmt, va_list ap) {
  while (*fmt) {
    if (*fmt != '%') {
      printf_putch(state, *fmt++);
      continue;
    }

    fmt++;
    bool left_justified = false;
    char sign = '\0';
    char padding = ' ';
    bool parsing_flags = true;
    while (parsing_flags) {
      switch (*fmt) {
        case '-': left_justified = true; fmt++; break;
        case '+': sign = '+'; fmt++; break;
        case ' ': sign = ' '; fmt++; break;
        case '0': padding = '0'; fmt++; break;
        case '#': fmt++; break;
        default: parsing_flags = false; break;
      }
    }

    size_t width = 0;
    while (*fmt >= '0' && *fmt <= '9') {
      width = width * 10 + *fmt - '0';
      fmt++;
    }

    if (*fmt == '.') {
      fmt++;
      while (*fmt >= '0' && *fmt <= '9') fmt++;
    }

    int length_level = 0;
    while (*fmt == 'l' || *fmt == 'h') {
      length_level += *fmt == 'l' ? 1 : -1;
      fmt++;
    }

    switch (*fmt) {
      case '\0': return;
      case '%': printf_char(state, '%', width, left_justified); break;
      case 'c': printf_char(state, (char)va_arg(ap, int), width, left_justified); break;
      case 's': printf_string(state, va_arg(ap, const char *), width, left_justified); break;
      case 'd':
      case 'i':
        if (length_level >= 2) {
          printf_signed(state, va_arg(ap, long long), width, left_justified, padding, sign);
        } else if (length_level == 1) {
          printf_signed(state, va_arg(ap, long), width, left_justified, padding, sign);
        } else {
          printf_signed(state, va_arg(ap, int), width, left_justified, padding, sign);
        }
        break;
      case 'u':
        if (length_level >= 2) {
          printf_unsigned(state, va_arg(ap, unsigned long long), 10, width, left_justified, padding, false);
        } else if (length_level == 1) {
          printf_unsigned(state, va_arg(ap, unsigned long), 10, width, left_justified, padding, false);
        } else {
          printf_unsigned(state, va_arg(ap, unsigned int), 10, width, left_justified, padding, false);
        }
        break;
      case 'x':
      case 'X':
      case 'p': {
        bool upper_case = *fmt == 'X';
        if (*fmt == 'p') {
          printf_putch(state, '0');
          printf_putch(state, 'x');
          printf_unsigned(state, (uintptr_t)va_arg(ap, void *), 16, width, left_justified, padding, false);
        } else if (length_level >= 2) {
          printf_unsigned(state, va_arg(ap, unsigned long long), 16, width, left_justified, padding, upper_case);
        } else if (length_level == 1) {
          printf_unsigned(state, va_arg(ap, unsigned long), 16, width, left_justified, padding, upper_case);
        } else {
          printf_unsigned(state, va_arg(ap, unsigned int), 16, width, left_justified, padding, upper_case);
        }
        break;
      }
      case 'o':
        if (length_level >= 2) {
          printf_unsigned(state, va_arg(ap, unsigned long long), 8, width, left_justified, padding, false);
        } else if (length_level == 1) {
          printf_unsigned(state, va_arg(ap, unsigned long), 8, width, left_justified, padding, false);
        } else {
          printf_unsigned(state, va_arg(ap, unsigned int), 8, width, left_justified, padding, false);
        }
        break;
      case 'f': case 'F': case 'e': case 'E': case 'g': case 'G': case 'a': case 'A':
        va_arg(ap, double);
        break;
      default:
        printf_putch(state, '%');
        printf_putch(state, *fmt);
        break;
    }
    fmt++;
  }
}

#endif
