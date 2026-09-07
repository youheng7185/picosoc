#ifndef FIRMWARE_H
#define FIRMWARE_H

#include <stdint.h>

void uart_init(void);
void print(const char *p);
void putchar(char c);
void print_hex(uint32_t v, int digits);
void print_dec(uint32_t v);

#endif