// #include "firmware.h"
// #include "qspi_nor.h"

// static inline void delay_us(unsigned int us) {
//     for (volatile int i = 0; i < (us * 17); i++)
//         __asm__ volatile ("nop");
// }

// int main() {
//     volatile unsigned int *gpio = (volatile unsigned int *)0x80000000;
//     gpio[1] = 0x0000ABCD;
//     gpio[1] = 0x00000000;

//     uart_init();

    

//     while (1);
//     return 0;
// }

#include "firmware.h"

volatile unsigned int *mdio = (volatile unsigned int *)0x80000400; // adjust address

#define MDIO_REG_CTRL    0
#define MDIO_REG_CFG     1
#define MDIO_REG_RDATA   2

#define MDIO_START       (1 << 0)
#define MDIO_RW_READ     (1 << 1)
#define MDIO_DONE        (1 << 2)

#define PHY_ADDR         0x00

static uint16_t mdio_read(uint8_t phy_addr, uint8_t reg_addr) {
    // 0x04: bit0:4 = phy_addr, bit5:9 = reg_addr
    mdio[MDIO_REG_CFG] = ((uint32_t)phy_addr & 0x1F) |
                         (((uint32_t)reg_addr & 0x1F) << 5);

    // start read transaction
    mdio[MDIO_REG_CTRL] = MDIO_START | MDIO_RW_READ;

    // wait for done
    while (!(mdio[MDIO_REG_CTRL] & MDIO_DONE));

    // read result from 0x08
    return (uint16_t)(mdio[MDIO_REG_RDATA] & 0xFFFF);
}

int main(void) {
    uart_init();

    print("PHY Register Dump (addr=0x00)\r\n");
    print("==============================\r\n");

    struct {
        uint8_t  reg;
        char    *name;
        uint16_t expected;
    } regs[] = {
        {  0, "Control Register",                          0x3100 },
        {  1, "Status Register",                           0x7849 },
        {  2, "PHY Identifier 1",                         0x0243 },
        {  3, "PHY Identifier 2",                         0x0C54 },
        {  4, "Auto-Neg Advertisement",                   0x01E1 },
        {  5, "Auto-Neg Link Partner Ability",            0x0000 },
        {  6, "Auto-Neg Expansion",                       0x0004 },
        {  7, "Auto-Neg Next Page Transmit",              0x2001 },
        {  8, "Auto-Neg Link Partner Next Page",          0x0000 },
        { 13, "MMD Access Control",                       0x0000 },
        { 14, "MMD Access Address Data",                  0x0000 },
        { 16, "PHY Specific Control",                     0x0002 },
        { 17, "PHY Interrupt Ctrl/Status",                0x0F00 },
        { 18, "PHY Status Monitoring",                    0x0208 },
        { 26, "Digital IO Pin Driving Control (26)",      0x1249 },
        { 27, "Digital IO Pin Driving Control (27)",      0x0012 },
        { 29, "Digital I/O Specific Control",             0x0082 },
    };

    uint32_t i;
    uint32_t num_regs = sizeof(regs) / sizeof(regs[0]);

    for (i = 0; i < num_regs; i++) {
        uint16_t val = mdio_read(PHY_ADDR, regs[i].reg);

        print("Reg[");
        print_dec(regs[i].reg);
        print("] ");
        print(regs[i].name);
        print(": 0x");
        print_hex(val, 4);
        print(" (expected: 0x");
        print_hex(regs[i].expected, 4);
        print(val == regs[i].expected ? ") OK\r\n" : ") MISMATCH\r\n");
    }

    print("Done\r\n");

    while (1);
    return 0;
}