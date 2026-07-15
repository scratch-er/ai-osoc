#include <klib.h>

#if !defined(__ISA_NATIVE__) || defined(__NATIVE_USE_KLIB__)

int iscntrl(int c) {
  return (c >= '\0' && c <= '\x1f') || c == '\x7f';
}

int isblank(int c) {
  return c == '\t' || c == ' ';
}

int isspace(int c) {
  return c == ' ' || (c >= '\t' && c <= '\r');
}

int isupper(int c) {
  return c >= 'A' && c <= 'Z';
}

int islower(int c) {
  return c >= 'a' && c <= 'z';
}

int isalpha(int c) {
  return isupper(c) || islower(c);
}

int isdigit(int c) {
  return c >= '0' && c <= '9';
}

int isxdigit(int c) {
  return isdigit(c) || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f');
}

int isalnum(int c) {
  return isalpha(c) || isdigit(c);
}

int ispunct(int c) {
  return (c >= '!' && c <= '/') ||
         (c >= ':' && c <= '@') ||
         (c >= '[' && c <= '`') ||
         (c >= '{' && c <= '~');
}

int isgraph(int c) {
  return c >= '!' && c <= '~';
}

int isprint(int c) {
  return c >= ' ' && c <= '~';
}

int tolower(int c) {
  return isupper(c) ? c - 'A' + 'a' : c;
}

int toupper(int c) {
  return islower(c) ? c - 'a' + 'A' : c;
}

#endif
