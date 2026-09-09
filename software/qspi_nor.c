#include "firmware.h"
#include "qspi_nor.h"
// ============================================================
// Hardware abstraction
// ============================================================

static volatile unsigned int *qspi = (volatile unsigned int *)0x80000300;

// ============================================================
// Internal helpers
// ============================================================

static inline void delay_us(unsigned int us) {
    for (volatile int i = 0; i < (us * 17); i++)
        __asm__ volatile ("nop");
}

static void wait_done(void) {
    while (!(qspi[REG_STATUS] & STATUS_DONE));
    qspi[REG_CTRL] = 0x00;
}

static void wait_flash_ready(void) {
    uint32_t status;
    do {
        qspi[REG_INSTR]    = 0x05;
        qspi[REG_DATA_CNT] = 0;
        qspi[REG_CTRL]     = CTRL_START | CTRL_DATA_MODE;
        wait_done();
        status = qspi[REG_DATA];
    } while (status & 0x01);
}

static void write_enable(void) {
    qspi[REG_INSTR]    = 0x06;
    qspi[REG_DATA_CNT] = 0x00;
    qspi[REG_CTRL]     = CTRL_START;
    wait_done();
}

static void flush_tx_fifo(void) {
    qspi[REG_CTRL] = CTRL_FLUSH_TX;
    qspi[REG_CTRL] = 0x00;
}

// Pack 4 bytes from uint8_t array into a 32-bit word (little-endian)
static uint32_t pack_word(const uint8_t *buf, uint32_t offset) {
    return ((uint32_t)buf[offset + 0] <<  0) |
           ((uint32_t)buf[offset + 1] <<  8) |
           ((uint32_t)buf[offset + 2] << 16) |
           ((uint32_t)buf[offset + 3] << 24);
}

// Unpack a 32-bit word into 4 bytes in uint8_t array (little-endian)
static void unpack_word(uint8_t *buf, uint32_t offset, uint32_t word) {
    buf[offset + 0] = (word >>  0) & 0xFF;
    buf[offset + 1] = (word >>  8) & 0xFF;
    buf[offset + 2] = (word >> 16) & 0xFF;
    buf[offset + 3] = (word >> 24) & 0xFF;
}

// ============================================================
// Public API
// ============================================================

// Initialize and reset flash, returns JEDEC ID
uint32_t flash_init(void) {
    qspi[REG_INSTR]    = 0x66;
    qspi[REG_DATA_CNT] = 0x00;
    qspi[REG_CTRL]     = CTRL_START;
    wait_done();

    qspi[REG_INSTR]    = 0x99;
    qspi[REG_DATA_CNT] = 0x00;
    qspi[REG_CTRL]     = CTRL_START;
    wait_done();

    delay_us(30);

    qspi[REG_INSTR]    = 0x9F;
    qspi[REG_DATA_CNT] = 0x03;
    qspi[REG_CTRL]     = CTRL_START | CTRL_DATA_MODE;
    wait_done();

    return qspi[REG_DATA];
}

// Erase one 4KB sector containing addr
void flash_sector_erase(uint32_t addr) {
    write_enable();
    qspi[REG_INSTR]    = 0x20;
    qspi[REG_ADDR]     = addr;
    qspi[REG_DATA_CNT] = 0x00;
    qspi[REG_CTRL]     = CTRL_START | CTRL_HAS_ADDR;
    wait_done();
    wait_flash_ready();
}

// Erase entire flash chip
void flash_erase_all(void) {
    uint32_t sector;
    for (sector = 0; sector < NUM_SECTORS; sector++) {
        flash_sector_erase(sector * SECTOR_SIZE);
    }
}

// Write one page (256 bytes) from buf to flash addr
// buf must be exactly PAGE_SIZE bytes
void flash_page_program(uint32_t addr, const uint8_t *buf) {
    write_enable();

    uint32_t i;
    for (i = 0; i < PAGE_SIZE; i += 4) {
        qspi[REG_DATA] = pack_word(buf, i);
    }

    qspi[REG_INSTR]    = 0x02;
    qspi[REG_ADDR]     = addr;
    qspi[REG_DATA_CNT] = PAGE_SIZE - 1;
    qspi[REG_CTRL]     = CTRL_START | CTRL_DATA_DIR | CTRL_HAS_ADDR | CTRL_DATA_MODE;
    wait_done();
    wait_flash_ready();
}

// Read len bytes from flash addr into buf
// len must be a multiple of 4, max 256
void flash_read(uint32_t addr, uint8_t *buf, uint32_t len) {
    flush_tx_fifo();

    qspi[REG_INSTR]    = 0x03;
    qspi[REG_ADDR]     = addr;
    qspi[REG_DATA_CNT] = len - 1;
    qspi[REG_CTRL]     = CTRL_START | CTRL_HAS_ADDR | CTRL_DATA_MODE;
    wait_done();

    uint32_t i;
    for (i = 0; i < len; i += 4) {
        unpack_word(buf, i, qspi[REG_DATA]);
    }
}

// Fast read len bytes from flash addr into buf (uses 8 dummy cycles)
// len must be a multiple of 4, max 256
void flash_fast_read(uint32_t addr, uint8_t *buf, uint32_t len) {
    flush_tx_fifo();

    qspi[REG_INSTR]    = 0x0B;
    qspi[REG_ADDR]     = addr;
    qspi[REG_DATA_CNT] = len - 1;
    qspi[REG_CTRL]     = CTRL_START | CTRL_HAS_ADDR | CTRL_DATA_MODE | CTRL_DUMMY(8);
    wait_done();

    uint32_t i;
    for (i = 0; i < len; i += 4) {
        unpack_word(buf, i, qspi[REG_DATA]);
    }
}