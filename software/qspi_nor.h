#ifndef QSPI_NOR_H
#define QSPI_NOR_H


#define CTRL_START       (1 << 0)
#define CTRL_DATA_DIR    (1 << 1)
#define CTRL_HAS_ADDR    (1 << 2)
#define CTRL_DATA_MODE   (1 << 3)
#define CTRL_DUMMY(n)    ((n) << 5)
#define CTRL_FLUSH_TX    (1 << 10)
#define CTRL_FLUSH_RX    (1 << 11)

#define REG_CTRL         0
#define REG_STATUS       1
#define REG_INSTR        2
#define REG_ADDR         3
#define REG_DATA_CNT     4
#define REG_DATA         5

#define STATUS_DONE      (1 << 0)

#define FLASH_SIZE       (8 * 1024 * 1024)
#define SECTOR_SIZE      4096
#define PAGE_SIZE        256
#define NUM_SECTORS      (FLASH_SIZE / SECTOR_SIZE)
#define NUM_PAGES        (FLASH_SIZE / PAGE_SIZE)


extern uint32_t flash_init(void);
extern void     flash_sector_erase(uint32_t addr);
extern void     flash_erase_all(void);
extern void     flash_page_program(uint32_t addr, const uint8_t *buf);
extern void     flash_read(uint32_t addr, uint8_t *buf, uint32_t len);
extern void     flash_fast_read(uint32_t addr, uint8_t *buf, uint32_t len);

#endif