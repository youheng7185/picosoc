#include "firmware.h"


int main() {
    volatile unsigned int *gpio = (volatile unsigned int *)0x80000000;
    gpio[1] = 0x0000ABCD;

    gpio[1] = 0x00000000;

    uart_init();
    //print("Eello world!\r\n");
    print_dec(123);
    // print_hex(0x12345678, 8);

    volatile unsigned int *fifo_loopback = (volatile unsigned int *)0x80000200;
    fifo_loopback[2] = 0x1234ABCD;
    fifo_loopback[2] = 0x12340000;
    // fifo_loopback[2] = 0x0000ABCD;

    print_hex(fifo_loopback[2], 8);
    print_hex(fifo_loopback[2], 8);
    print_hex(fifo_loopback[2], 8);

    while(1);

    return 0;
}