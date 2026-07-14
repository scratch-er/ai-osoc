#include <am.h>
#include <klib.h>
#include <klib-macros.h>
#include <stdarg.h>

#if !defined(__ISA_NATIVE__) || defined(__NATIVE_USE_KLIB__)

int printf(const char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  char buf[1024];
  int ret = vsnprintf(buf, sizeof(buf), fmt, ap);
  va_end(ap);
  int n = ret < (int)sizeof(buf) ? ret : (int)sizeof(buf) - 1;
  for (int i = 0; i < n; i++) putch(buf[i]);
  return ret;
}

static void out_char(char **out, size_t *left, int *cnt, char ch) {
  if (*left > 1) {
    **out = ch;
    (*out)++;
    (*left)--;
  }
  (*cnt)++;
}

static void out_str(char **out, size_t *left, int *cnt, const char *s) {
  if (s == NULL) s = "(null)";
  while (*s) out_char(out, left, cnt, *s++);
}

static void out_uint(char **out, size_t *left, int *cnt, unsigned int val, unsigned int base, bool neg) {
  char buf[16];
  int n = 0;
  if (neg) out_char(out, left, cnt, '-');
  do {
    unsigned int digit = val % base;
    buf[n++] = digit < 10 ? '0' + digit : 'a' + digit - 10;
    val /= base;
  } while (val != 0);
  while (n > 0) out_char(out, left, cnt, buf[--n]);
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
  char *p = out;
  size_t left = n;
  int cnt = 0;

  for (; *fmt; fmt++) {
    if (*fmt != '%') {
      out_char(&p, &left, &cnt, *fmt);
      continue;
    }

    fmt++;
    if (*fmt == '\0') break;
    switch (*fmt) {
      case '%': out_char(&p, &left, &cnt, '%'); break;
      case 'c': out_char(&p, &left, &cnt, (char)va_arg(ap, int)); break;
      case 's': out_str(&p, &left, &cnt, va_arg(ap, const char *)); break;
      case 'd': {
        int v = va_arg(ap, int);
        unsigned int u = v < 0 ? -(unsigned int)v : (unsigned int)v;
        out_uint(&p, &left, &cnt, u, 10, v < 0);
        break;
      }
      case 'u': out_uint(&p, &left, &cnt, va_arg(ap, unsigned int), 10, false); break;
      case 'x': out_uint(&p, &left, &cnt, va_arg(ap, unsigned int), 16, false); break;
      case 'p':
        out_str(&p, &left, &cnt, "0x");
        out_uint(&p, &left, &cnt, (unsigned int)(uintptr_t)va_arg(ap, void *), 16, false);
        break;
      default:
        out_char(&p, &left, &cnt, '%');
        out_char(&p, &left, &cnt, *fmt);
        break;
    }
  }

  if (n > 0) *p = '\0';
  return cnt;
}

#endif
