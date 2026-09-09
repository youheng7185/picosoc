#include "firmware.h"
#include "qspi_nor.h"

static inline void delay_us(unsigned int us) {
    for (volatile int i = 0; i < (us * 17); i++)
        __asm__ volatile ("nop");
}

int main() {
    volatile unsigned int *gpio = (volatile unsigned int *)0x80000000;
    gpio[1] = 0x0000ABCD;
    gpio[1] = 0x00000000;

    uart_init();
uint32_t jedec = flash_init();
    print("JEDEC ID: 0x");
    print_hex(jedec, 8);
    print("\r\n");

    // Erase
    print("Erasing...\r\n");
    flash_erase_all();
    print("Erase done\r\n");

    // Build a page of test data
    uint8_t write_buf[PAGE_SIZE];
    uint8_t read_buf[PAGE_SIZE];
    uint32_t i;
    for (i = 0; i < PAGE_SIZE; i++)
        write_buf[i] = (uint8_t)i;

    // Write all pages
    print("Writing...\r\n");
    uint32_t page;
    for (page = 0; page < NUM_PAGES; page++) {
        flash_page_program(page * PAGE_SIZE, write_buf);
    }
    print("Write done\r\n");

    // Verify all pages with normal read
    print("Verifying (normal read)...\r\n");
    uint32_t fail_count = 0;
    for (page = 0; page < NUM_PAGES; page++) {
        flash_read(page * PAGE_SIZE, read_buf, PAGE_SIZE);
        for (i = 0; i < PAGE_SIZE; i++) {
            if (read_buf[i] != write_buf[i]) {
                fail_count++;
                print("FAIL page ");
                print_dec(page);
                print(" byte ");
                print_dec(i);
                print(" got 0x");
                print_hex(read_buf[i], 2);
                print(" expected 0x");
                print_hex(write_buf[i], 2);
                print("\r\n");
            }
        }
    }

    // Verify all pages with fast read
    print("Verifying (fast read)...\r\n");
    for (page = 0; page < NUM_PAGES; page++) {
        flash_fast_read(page * PAGE_SIZE, read_buf, PAGE_SIZE);
        for (i = 0; i < PAGE_SIZE; i++) {
            if (read_buf[i] != write_buf[i]) {
                fail_count++;
                print("FAIL fast page ");
                print_dec(page);
                print(" byte ");
                print_dec(i);
                print(" got 0x");
                print_hex(read_buf[i], 2);
                print(" expected 0x");
                print_hex(write_buf[i], 2);
                print("\r\n");
            }
        }
    }

    if (fail_count == 0)
        print("All OK!\r\n");
    else {
        print("Total failures: ");
        print_dec(fail_count);
        print("\r\n");
    }

    while (1);
    return 0;
}