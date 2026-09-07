#include "firmware.h"

int main() {
    volatile unsigned int *gpio = (volatile unsigned int *)0x80000000;
    gpio[1] = 0x0000ABCD;

    gpio[1] = 0x00000000;

    uart_init();
    while(1) {
        print("Hello world!\r\n");
        //putchar('e');
    }

    while(1);

    return 0;
}