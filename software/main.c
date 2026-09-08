#include "firmware.h"

static inline void delay_us(unsigned int us) {
    // 16.5 iterations per microsecond, rounded up to 17 for safety
    for (volatile int i = 0; i < (us * 17); i++)
        __asm__ volatile ("nop");
}

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
    //fifo_loopback[2] = 0x0000ABCD;

    print_hex(fifo_loopback[2], 8);
    print_hex(fifo_loopback[2], 8);
    print_hex(fifo_loopback[2], 8);

    volatile unsigned int *qspi = (volatile unsigned int *)0x80000300;
    // --- Step 1: Reset enable (0x66) ---
    qspi[2] = 0x66;
    qspi[4] = 0x00;
    qspi[0] = 0x01;
    while (!(qspi[1] & 0x1));
    qspi[0] = 0x00;

    // --- Step 2: Reset (0x99) ---
    qspi[2] = 0x99;
    qspi[4] = 0x00;
    qspi[0] = 0x01;
    while (!(qspi[1] & 0x1));
    qspi[0] = 0x00;

    // delay ~30us here

    // --- Step 3: Read JEDEC ID (0x9F) ---
    qspi[2] = 0x9F;
    qspi[4] = 0x03;           // 3 bytes — fits in one 32-bit FIFO word
    qspi[0] = 0x01;
    while (!(qspi[1] & 0x1));
    qspi[0] = 0x00;

    // --- Step 4: One read gets all 3 bytes packed into 32 bits ---
    unsigned int jedec_id = qspi[5];
    print("JEDEC ID: ");
    print_hex(jedec_id, 8);

    while(1) {
        print("hello world\r\n");
    }
    
    while(1);

    return 0;
}