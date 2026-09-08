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

    // volatile unsigned int *fifo_loopback = (volatile unsigned int *)0x80000200;
    // fifo_loopback[2] = 0x1234ABCD;
    // fifo_loopback[2] = 0x12340000;
    // //fifo_loopback[2] = 0x0000ABCD;

    // print_hex(fifo_loopback[2], 8);
    // print_hex(fifo_loopback[2], 8);
    // print_hex(fifo_loopback[2], 8);

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
    delay_us(30);

    // --- Step 3: Read JEDEC ID (0x9F) ---
    qspi[2] = 0x9F;
    qspi[4] = 0x03;           // 3 bytes — fits in one 32-bit FIFO word
    qspi[0] = 0x09; // data_dir 01, start 1
    while (!(qspi[1] & 0x1));
    qspi[0] = 0x00;

    // --- Step 4: One read gets all 3 bytes packed into 32 bits ---
    unsigned int jedec_id = qspi[5];
    print("JEDEC ID: ");
    print_hex(jedec_id, 8);
    print("\r\n");

    /* Write Enable (0x06) */
    qspi[2] = 0x06;
    qspi[4] = 0x00;
    qspi[0] = 0x01;

    while (!(qspi[1] & 0x01));

    qspi[0] = 0x00;

    /* Sector Erase 4KB (0x20) */
    qspi[2] = 0x20;
    qspi[3] = 0x000000;
    qspi[4] = 0x00;

    /*
    * CTRL:
    * bit 0 = start
    * bit 2 = has_address
    */
    qspi[0] = 0x05;

    while (!(qspi[1] & 0x01));

    qspi[0] = 0x00;

    uint32_t data;
    while (1) {

        qspi[2] = 0x05;
        qspi[4] = 0x00;       // 1 byte
        qspi[0] = 0x09;       // start + single data mode

        while (!(qspi[1] & 0x01));

        qspi[0] = 0x00;

        data = qspi[5];

        if (!(data & 0x01))
            break;
    }

    print("Sector erase done\r\n");

    /* ============================================================
    * STEP 2: WRITE ENABLE AGAIN
    * ============================================================ */

    qspi[2] = 0x06;
    qspi[4] = 0x00;
    qspi[0] = 0x01;

    while (!(qspi[1] & 0x01));

    qspi[0] = 0x00;

    uint32_t i;
    for (i = 0; i < 200; i += 4) {
        data = ((uint32_t)(i + 0) <<  0) |
            ((uint32_t)(i + 1) <<  8) |
            ((uint32_t)(i + 2) << 16) |
            ((uint32_t)(i + 3) << 24);
        qspi[5] = data;
    }

    print("FIFO filled\r\n");

    /* ============================================================
    * STEP 4: PAGE PROGRAM 256 BYTES AT 0x000000
    * ============================================================ */

    qspi[2] = 0x02;
    qspi[3] = 0x000000;
    qspi[4] = 199;        // 256 bytes, lesser first

    qspi[0] = 0x0F;

    while (!(qspi[1] & 0x01));

    qspi[0] = 0x00;


    /* Wait until Page Program finishes */

    while (1) {

        qspi[2] = 0x05;
        qspi[4] = 0x00;
        qspi[0] = 0x09;

        while (!(qspi[1] & 0x01));

        qspi[0] = 0x00;

        data = qspi[5];

        if (!(data & 0x01))
            break;
    }

    print("Page program done\r\n");

    /* ============================================================
    * STEP 5: READ 256 BYTES BACK
    * ============================================================ */

    qspi[2] = 0x03;           // Fast Read
    qspi[3] = 0x000000;
    qspi[4] = 199;            // 256 bytes

    // drain fifo manually
    // print_hex(qspi[5], 8);
    // print_hex(qspi[5], 8);
    // print_hex(qspi[5], 8);

    /*
    * CTRL:
    *
    * bit 0     start
    * bit 2     has_address
    * bits 4:3  data_mode = 01
    * bits 9:5  dummy_cnt = 8
    *
    * 0x01 + 0x04 + 0x08 + (8 << 5)
    */
    qspi[0] = 0x01 | 0x04 | 0x08;

    while (!(qspi[1] & 0x01));

    qspi[0] = 0x00;

    print("\r\nRead data:\r\n");

    for (i = 0; i < 64; i++) {
        uint32_t read_data;
        read_data = qspi[5];

        data =
                (((i * 4) + 0) << 0)  |
                (((i * 4) + 1) << 8)  |
                (((i * 4) + 2) << 16) |
                (((i * 4) + 3) << 24);

            print("Read:     0x");
            print_hex(read_data, 8);

            print(" Expected: 0x");
            print_hex(data, 8);

            if (read_data == data)
                print(" OK\r\n");
            else
                print(" FAIL\r\n");
    }

    print("\r\nfast read\r\n");

    qspi[2] = 0x0B;           // Fast Read
    qspi[3] = 0x000000;
    qspi[4] = 199;            // 256 bytes

    // drain fifo manually
    // print_hex(qspi[5], 8);
    // print_hex(qspi[5], 8);
    // print_hex(qspi[5], 8);

    /*
    * CTRL:
    *
    * bit 0     start
    * bit 2     has_address
    * bits 4:3  data_mode = 01
    * bits 9:5  dummy_cnt = 8
    *
    * 0x01 + 0x04 + 0x08 + (8 << 5)
    */
    qspi[0] = 0x01 | 0x04 | 0x08 | (8 << 5);

    while (!(qspi[1] & 0x01));

    qspi[0] = 0x00;

    print("\r\nRead data:\r\n");

    for (i = 0; i < 64; i++) {
        uint32_t read_data;
        read_data = qspi[5];

        data =
                (((i * 4) + 0) << 0)  |
                (((i * 4) + 1) << 8)  |
                (((i * 4) + 2) << 16) |
                (((i * 4) + 3) << 24);

            print("Read:     0x");
            print_hex(read_data, 8);

            print(" Expected: 0x");
            print_hex(data, 8);

            if (read_data == data)
                print(" OK\r\n");
            else
                print(" FAIL\r\n");
    }

    while(1) {
        print(".");
    }
    
    while(1);

    return 0;
}