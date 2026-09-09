// #include "firmware.h"

// static inline void delay_us(unsigned int us) {
//     // 16.5 iterations per microsecond, rounded up to 17 for safety
//     for (volatile int i = 0; i < (us * 17); i++)
//         __asm__ volatile ("nop");
// }

// int main() {
//     volatile unsigned int *gpio = (volatile unsigned int *)0x80000000;
//     gpio[1] = 0x0000ABCD;

//     gpio[1] = 0x00000000;

//     uart_init();
//     //print("Eello world!\r\n");
//     print_dec(123);
//     // print_hex(0x12345678, 8);

//     // volatile unsigned int *fifo_loopback = (volatile unsigned int *)0x80000200;
//     // fifo_loopback[2] = 0x1234ABCD;
//     // fifo_loopback[2] = 0x12340000;
//     // //fifo_loopback[2] = 0x0000ABCD;

//     // print_hex(fifo_loopback[2], 8);
//     // print_hex(fifo_loopback[2], 8);
//     // print_hex(fifo_loopback[2], 8);

//     volatile unsigned int *qspi = (volatile unsigned int *)0x80000300;
//     // --- Step 1: Reset enable (0x66) ---
//     qspi[2] = 0x66;
//     qspi[4] = 0x00;
//     qspi[0] = 0x01;
//     while (!(qspi[1] & 0x1));
//     qspi[0] = 0x00;

//     // --- Step 2: Reset (0x99) ---
//     qspi[2] = 0x99;
//     qspi[4] = 0x00;
//     qspi[0] = 0x01;
//     while (!(qspi[1] & 0x1));
//     qspi[0] = 0x00;

//     // delay ~30us here
//     delay_us(30);

//     // --- Step 3: Read JEDEC ID (0x9F) ---
//     qspi[2] = 0x9F;
//     qspi[4] = 0x03;           // 3 bytes — fits in one 32-bit FIFO word
//     qspi[0] = 0x09; // data_dir 01, start 1
//     while (!(qspi[1] & 0x1));
//     qspi[0] = 0x00;

//     // --- Step 4: One read gets all 3 bytes packed into 32 bits ---
//     unsigned int jedec_id = qspi[5];
//     print("JEDEC ID: ");
//     print_hex(jedec_id, 8);
//     print("\r\n");

//     /* Write Enable (0x06) */
//     qspi[2] = 0x06;
//     qspi[4] = 0x00;
//     qspi[0] = 0x01;

//     while (!(qspi[1] & 0x01));

//     qspi[0] = 0x00;

//     /* Sector Erase 4KB (0x20) */
//     qspi[2] = 0x20;
//     qspi[3] = 0x100000;
//     qspi[4] = 0x00;

//     /*
//     * CTRL:
//     * bit 0 = start
//     * bit 2 = has_address
//     */
//     qspi[0] = 0x05;

//     while (!(qspi[1] & 0x01));

//     qspi[0] = 0x00;

//     uint32_t data;
//     while (1) {

//         qspi[2] = 0x05;
//         qspi[4] = 0x00;       // 1 byte
//         qspi[0] = 0x09;       // start + single data mode

//         while (!(qspi[1] & 0x01));

//         qspi[0] = 0x00;

//         data = qspi[5];

//         if (!(data & 0x01))
//             break;
//     }

//     print("Sector erase done\r\n");

//     /* ============================================================
//     * STEP 2: WRITE ENABLE AGAIN
//     * ============================================================ */

//     qspi[2] = 0x06;
//     qspi[4] = 0x00;
//     qspi[0] = 0x01;

//     while (!(qspi[1] & 0x01));

//     qspi[0] = 0x00;

//     uint32_t i;
//     for (i = 0; i < 255; i += 4) {
//         data = ((uint32_t)(i + 0) <<  0) |
//             ((uint32_t)(i + 1) <<  8) |
//             ((uint32_t)(i + 2) << 16) |
//             ((uint32_t)(i + 3) << 24);
//         qspi[5] = data;
//     }

//     print("FIFO filled\r\n");

//     /* ============================================================
//     * STEP 4: PAGE PROGRAM 256 BYTES AT 0x000000
//     * ============================================================ */

//     qspi[2] = 0x02;
//     qspi[3] = 0x100000;
//     qspi[4] = 255;        // 256 bytes, lesser first

//     qspi[0] = 0x0F;

//     while (!(qspi[1] & 0x01));

//     qspi[0] = 0x00;


//     /* Wait until Page Program finishes */

//     while (1) {

//         qspi[2] = 0x05;
//         qspi[4] = 0x00;
//         qspi[0] = 0x09;

//         while (!(qspi[1] & 0x01));

//         qspi[0] = 0x00;

//         data = qspi[5];

//         if (!(data & 0x01))
//             break;
//     }

//     print("Page program done\r\n");

//     /* ============================================================
//     * STEP 5: READ 256 BYTES BACK
//     * ============================================================ */

//     qspi[2] = 0x03;           // Fast Read
//     qspi[3] = 0x000000;
//     qspi[4] = 255;            // 256 bytes

//     // drain fifo manually
//     // print_hex(qspi[5], 8);
//     // print_hex(qspi[5], 8);
//     // print_hex(qspi[5], 8);

//     /*
//     * CTRL:
//     *
//     * bit 0     start
//     * bit 2     has_address
//     * bits 4:3  data_mode = 01
//     * bits 9:5  dummy_cnt = 8
//     *
//     * 0x01 + 0x04 + 0x08 + (8 << 5)
//     */
//     qspi[0] = 0x01 | 0x04 | 0x08;

//     while (!(qspi[1] & 0x01));

//     qspi[0] = 0x00;

//     print("\r\nRead data:\r\n");

//     for (i = 0; i < 64; i++) {
//         uint32_t read_data;
//         read_data = qspi[5];

//         data =
//                 (((i * 4) + 0) << 0)  |
//                 (((i * 4) + 1) << 8)  |
//                 (((i * 4) + 2) << 16) |
//                 (((i * 4) + 3) << 24);

//             print("Read:     0x");
//             print_hex(read_data, 8);

//             print(" Expected: 0x");
//             print_hex(data, 8);

//             if (read_data == data)
//                 print(" OK\r\n");
//             else
//                 print(" FAIL\r\n");
//     }

//     print("\r\nfast read\r\n");

//     qspi[2] = 0x0B;           // Fast Read
//     qspi[3] = 0x100000;
//     qspi[4] = 255;            // 256 bytes

//     // drain fifo manually
//     // print_hex(qspi[5], 8);
//     // print_hex(qspi[5], 8);
//     // print_hex(qspi[5], 8);

//     /*
//     * CTRL:
//     *
//     * bit 0     start
//     * bit 2     has_address
//     * bits 4:3  data_mode = 01
//     * bits 9:5  dummy_cnt = 8
//     *
//     * 0x01 + 0x04 + 0x08 + (8 << 5)
//     */
//     qspi[0] = 0x01 | 0x04 | 0x08 | (8 << 5);

//     while (!(qspi[1] & 0x01));

//     qspi[0] = 0x00;

//     print("\r\nRead data:\r\n");

//     for (i = 0; i < 64; i++) {
//         uint32_t read_data;
//         read_data = qspi[5];

//         data =
//                 (((i * 4) + 0) << 0)  |
//                 (((i * 4) + 1) << 8)  |
//                 (((i * 4) + 2) << 16) |
//                 (((i * 4) + 3) << 24);

//             print("Read:     0x");
//             print_hex(read_data, 8);

//             print(" Expected: 0x");
//             print_hex(data, 8);

//             if (read_data == data)
//                 print(" OK\r\n");
//             else
//                 print(" FAIL\r\n");
//     }

//     while(1) {
//         // print(".");
//     }
    
//     while(1);

//     return 0;
// }

#include "firmware.h"

static inline void delay_us(unsigned int us) {
    for (volatile int i = 0; i < (us * 17); i++)
        __asm__ volatile ("nop");
}

volatile unsigned int *qspi = (volatile unsigned int *)0x80000300;

// CTRL register bit definitions
#define CTRL_START       (1 << 0)
#define CTRL_DATA_DIR    (1 << 1)   // 1 = write to NOR
#define CTRL_HAS_ADDR    (1 << 2)
#define CTRL_DATA_MODE   (1 << 3)   // bits 4:3, 01 = data transfer
#define CTRL_DUMMY(n)    ((n) << 5) // bits 9:5

#define REG_CTRL         0
#define REG_STATUS       1
#define REG_INSTR        2
#define REG_ADDR         3
#define REG_DATA_CNT     4
#define REG_DATA         5

#define STATUS_DONE      (1 << 0)

#define FLASH_SIZE       (8 * 1024 * 1024)   // 8MB
#define SECTOR_SIZE      4096
#define PAGE_SIZE        256
#define NUM_SECTORS      (FLASH_SIZE / SECTOR_SIZE)
#define NUM_PAGES        (FLASH_SIZE / PAGE_SIZE)

static void wait_done(void) {
    while (!(qspi[REG_STATUS] & STATUS_DONE));
    qspi[REG_CTRL] = 0x00;
}

static void wait_flash_ready(void) {
    uint32_t status;
    do {
        qspi[REG_INSTR]    = 0x05;  // Read Status Register
        qspi[REG_DATA_CNT] = 0;     // 1 byte
        qspi[REG_CTRL]     = CTRL_START | CTRL_DATA_MODE;
        wait_done();
        status = qspi[REG_DATA];
    } while (status & 0x01);        // WIP bit
}

static void write_enable(void) {
    qspi[REG_INSTR]    = 0x06;
    qspi[REG_DATA_CNT] = 0x00;
    qspi[REG_CTRL]     = CTRL_START;
    wait_done();
}

static void sector_erase(uint32_t addr) {
    write_enable();
    qspi[REG_INSTR]    = 0x20;  // Sector Erase 4KB
    qspi[REG_ADDR]     = addr;
    qspi[REG_DATA_CNT] = 0x00;
    qspi[REG_CTRL]     = CTRL_START | CTRL_HAS_ADDR;
    wait_done();
    wait_flash_ready();
}

static void page_program(uint32_t addr, uint32_t pattern_base) {
    write_enable();

    // Fill TX FIFO with 256 bytes of pattern
    uint32_t i;
    for (i = 0; i < 256; i += 4) {
        uint32_t b = pattern_base + i;
        qspi[REG_DATA] = ((b + 0) <<  0) |
                         ((b + 1) <<  8) |
                         ((b + 2) << 16) |
                         ((b + 3) << 24);
    }

    qspi[REG_INSTR]    = 0x02;  // Page Program
    qspi[REG_ADDR]     = addr;
    qspi[REG_DATA_CNT] = 255;   // 256 bytes

    qspi[REG_CTRL] = CTRL_START | CTRL_DATA_DIR | CTRL_HAS_ADDR | CTRL_DATA_MODE;
    wait_done();
    wait_flash_ready();
}

static int verify_page(uint32_t addr, uint32_t pattern_base) {
    // flush TX fifo before read
    qspi[REG_CTRL] = (1 << 10);
    qspi[REG_CTRL] = 0x00;

    qspi[REG_INSTR]    = 0x03;  // Read
    qspi[REG_ADDR]     = addr;
    qspi[REG_DATA_CNT] = 255;
    qspi[REG_CTRL]     = CTRL_START | CTRL_HAS_ADDR | CTRL_DATA_MODE;
    wait_done();

    uint32_t i;
    int pass = 1;
    for (i = 0; i < 64; i++) {
        uint32_t b = pattern_base + (i * 4);
        uint32_t expected = ((b + 0) <<  0) |
                            ((b + 1) <<  8) |
                            ((b + 2) << 16) |
                            ((b + 3) << 24);
        uint32_t got = qspi[REG_DATA];
        if (got != expected) {
            pass = 0;
            print("FAIL at addr 0x");
            print_hex(addr + i * 4, 8);
            print(" got 0x");
            print_hex(got, 8);
            print(" expected 0x");
            print_hex(expected, 8);
            print("\r\n");
        }
    }
    return pass;
}

int main() {
    volatile unsigned int *gpio = (volatile unsigned int *)0x80000000;
    gpio[1] = 0x0000ABCD;
    gpio[1] = 0x00000000;

    uart_init();

    // Flash reset sequence
    qspi[REG_INSTR] = 0x66;
    qspi[REG_DATA_CNT] = 0x00;
    qspi[REG_CTRL] = CTRL_START;
    wait_done();

    qspi[REG_INSTR] = 0x99;
    qspi[REG_DATA_CNT] = 0x00;
    qspi[REG_CTRL] = CTRL_START;
    wait_done();

    delay_us(30);

    // Read JEDEC ID
    qspi[REG_INSTR]    = 0x9F;
    qspi[REG_DATA_CNT] = 0x03;
    qspi[REG_CTRL]     = CTRL_START | CTRL_DATA_MODE;
    wait_done();
    print("JEDEC ID: 0x");
    print_hex(qspi[REG_DATA], 8);
    print("\r\n");

    // =========================================================
    // PHASE 1: Erase all sectors
    // =========================================================
    print("Erasing entire 8MB flash...\r\n");

    uint32_t sector;
    for (sector = 0; sector < NUM_SECTORS; sector++) {
        uint32_t addr = sector * SECTOR_SIZE;
        sector_erase(addr);

        if ((sector & 0xF) == 0xF) {
            print("Erased sector ");
            print_dec(sector + 1);
            print(" / ");
            print_dec(NUM_SECTORS);
            print("\r\n");
        }
    }

    print("Erase complete\r\n");

    // =========================================================
    // PHASE 2: Write all pages
    // =========================================================
    print("Writing all pages...\r\n");

    uint32_t page;
    for (page = 0; page < NUM_PAGES; page++) {
        uint32_t addr         = page * PAGE_SIZE;
        uint32_t pattern_base = addr & 0xFF; // byte offset wraps at 256

        page_program(addr, pattern_base);

        if ((page & 0xFF) == 0xFF) {
            print("Written page ");
            print_dec(page + 1);
            print(" / ");
            print_dec(NUM_PAGES);
            print("\r\n");
        }
    }

    print("Write complete\r\n");

    // =========================================================
    // PHASE 3: Verify all pages
    // =========================================================
    print("Verifying...\r\n");

    uint32_t fail_count = 0;
    for (page = 0; page < NUM_PAGES; page++) {
        uint32_t addr         = page * PAGE_SIZE;
        uint32_t pattern_base = addr & 0xFF;

        if (!verify_page(addr, pattern_base)) {
            fail_count++;
        }

        if ((page & 0xFF) == 0xFF) {
            print("Verified page ");
            print_dec(page + 1);
            print(" / ");
            print_dec(NUM_PAGES);
            print("\r\n");
        }
    }

    if (fail_count == 0) {
        print("All pages verified OK!\r\n");
    } else {
        print("FAILED pages: ");
        print_dec(fail_count);
        print("\r\n");
    }

    while (1);
    return 0;
}