#include "Vaxi_qspi_nor.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <cassert>
#include <cstdio>

vluint64_t sim_time = 0;

// -------------------------------------------------
// REGISTER ADDRESSES
// -------------------------------------------------
// 0x00  CTRL      [0]=start [1]=data_dir [2]=has_address [4:3]=data_mode [9:5]=dummy_cnt
// 0x04  STATUS    [0]=done  [1]=tx_empty [2]=tx_full [3]=rx_empty [4]=rx_full
// 0x08  INSTR     [7:0]=instruction byte
// 0x0C  ADDR      [31:0]=NOR flash address
// 0x10  DATA_CNT  [7:0]=data_cnt
// 0x14  DATA      FIFO read/write port

#define REG_CTRL      0x00
#define REG_STATUS    0x04
#define REG_INSTR     0x08
#define REG_ADDR      0x0C
#define REG_DATA_CNT  0x10
#define REG_DATA      0x14

// CTRL bit helpers
#define CTRL_START        (1u << 0)
#define CTRL_DATA_DIR     (1u << 1)   // 1 = write to NOR
#define CTRL_HAS_ADDR     (1u << 2)
#define CTRL_DATA_MODE(m) (((m) & 0x3u) << 3)
#define CTRL_DUMMY_CNT(d) (((d) & 0x1Fu) << 5)

// STATUS bit helpers
#define STATUS_DONE      (1u << 0)
#define STATUS_TX_EMPTY  (1u << 1)
#define STATUS_TX_FULL   (1u << 2)
#define STATUS_RX_EMPTY  (1u << 3)
#define STATUS_RX_FULL   (1u << 4)

// -------------------------------------------------
// TICK / DELAY
// -------------------------------------------------
void tick(Vaxi_qspi_nor *dut, VerilatedVcdC *tfp) {
    dut->S_AXI_ACLK = 0;
    dut->eval();
    tfp->dump(sim_time++);

    dut->S_AXI_ACLK = 1;
    dut->eval();
    tfp->dump(sim_time++);
}

void delay(Vaxi_qspi_nor *dut, VerilatedVcdC *tfp, uint32_t count) {
    for (uint32_t i = 0; i < count; i++)
        tick(dut, tfp);
}

// -------------------------------------------------
// AXI WRITE
// -------------------------------------------------
void axi_write(Vaxi_qspi_nor *dut, VerilatedVcdC *tfp,
               uint32_t addr, uint32_t data)
{
    dut->S_AXI_AWADDR  = addr;
    dut->S_AXI_AWVALID = 1;

    dut->S_AXI_WDATA   = data;
    dut->S_AXI_WSTRB   = 0xF;
    dut->S_AXI_WVALID  = 1;

    dut->S_AXI_BREADY  = 1;

    // Wait for AWREADY
    while (!dut->S_AXI_AWREADY)
        tick(dut, tfp);

    tick(dut, tfp);

    dut->S_AXI_AWVALID = 0;
    dut->S_AXI_WVALID  = 0;

    // Wait for BVALID
    while (!dut->S_AXI_BVALID)
        tick(dut, tfp);

    tick(dut, tfp);
    dut->S_AXI_BREADY = 0;
}

// -------------------------------------------------
// AXI READ
// -------------------------------------------------
uint32_t axi_read(Vaxi_qspi_nor *dut, VerilatedVcdC *tfp,
                  uint32_t addr)
{
    // Wait for ARREADY
    while (!dut->S_AXI_ARREADY)
        tick(dut, tfp);

    dut->S_AXI_ARADDR  = addr;
    dut->S_AXI_ARVALID = 1;
    dut->S_AXI_RREADY  = 1;

    tick(dut, tfp);
    dut->S_AXI_ARVALID = 0;

    // Wait for RVALID
    while (!dut->S_AXI_RVALID)
        tick(dut, tfp);

    uint32_t data = dut->S_AXI_RDATA;

    tick(dut, tfp);
    dut->S_AXI_RREADY = 0;

    return data;
}

// -------------------------------------------------
// HELPERS
// -------------------------------------------------

// Poll STATUS register until done bit is set, then clear start
void wait_done(Vaxi_qspi_nor *dut, VerilatedVcdC *tfp,
               const char *label, int max_ticks = 2000)
{
    int waited = 0;
    uint32_t status;
    do {
        tick(dut, tfp);
        status = axi_read(dut, tfp, REG_STATUS);
        waited++;
        if (waited > max_ticks) {
            std::cerr << "[TIMEOUT] " << label << " did not complete!\n";
            break;
        }
    } while (!(status & STATUS_DONE));

    std::cout << "[DONE] " << label << " (status=0x"
              << std::hex << status << ")\n";

    // Clear start
    axi_write(dut, tfp, REG_CTRL, 0x00);
}

// Push one 32-bit word into the RX FIFO (write data to flash)
void push_rx_fifo(Vaxi_qspi_nor *dut, VerilatedVcdC *tfp, uint32_t word)
{
    // Check RX not full before writing
    uint32_t status = axi_read(dut, tfp, REG_STATUS);
    if (status & STATUS_RX_FULL) {
        std::cerr << "[WARN] RX FIFO full, cannot push 0x" << std::hex << word << "\n";
        return;
    }
    axi_write(dut, tfp, REG_DATA, word);
}

// Pull one 32-bit word from the TX FIFO (read data from flash)
uint32_t pull_tx_fifo(Vaxi_qspi_nor *dut, VerilatedVcdC *tfp)
{
    uint32_t status = axi_read(dut, tfp, REG_STATUS);
    if (status & STATUS_TX_EMPTY) {
        std::cerr << "[WARN] TX FIFO empty, nothing to pull\n";
        return 0xDEADBEEF;
    }
    return axi_read(dut, tfp, REG_DATA);
}

// Build CTRL word from individual fields
uint32_t make_ctrl(bool start, bool data_dir, bool has_addr,
                   uint8_t data_mode, uint8_t dummy_cnt)
{
    return (start       ? CTRL_START        : 0)
         | (data_dir    ? CTRL_DATA_DIR     : 0)
         | (has_addr    ? CTRL_HAS_ADDR     : 0)
         | CTRL_DATA_MODE(data_mode)
         | CTRL_DUMMY_CNT(dummy_cnt);
}

// -------------------------------------------------
// MAIN
// -------------------------------------------------
int main(int argc, char **argv) {

    Verilated::commandArgs(argc, argv);

    Vaxi_qspi_nor *dut = new Vaxi_qspi_nor;

    VerilatedVcdC *tfp = new VerilatedVcdC;
    Verilated::traceEverOn(true);
    dut->trace(tfp, 99);
    tfp->open("waveform.vcd");

    // Initialize signals
    dut->S_AXI_ARESETN = 0;
    dut->S_AXI_AWVALID = 0;
    dut->S_AXI_WVALID  = 0;
    dut->S_AXI_BREADY  = 0;
    dut->S_AXI_ARVALID = 0;
    dut->S_AXI_RREADY  = 0;
    dut->miso_i        = 0;

    // Reset sequence
    delay(dut, tfp, 5);
    dut->S_AXI_ARESETN = 1;
    delay(dut, tfp, 5);

    std::cout << "Starting AXI QSPI NOR test\n";

    // =================================================================
    // TEST 1: Command only (WREN, 0x06) — format: 1-0-0
    //   instr=0x06, no address, no data
    // =================================================================
    std::cout << "\n[TEST 1] Command only: WREN (0x06)\n";

    axi_write(dut, tfp, REG_INSTR,    0x06);
    axi_write(dut, tfp, REG_DATA_CNT, 0x00);
    axi_write(dut, tfp, REG_ADDR,     0x00000000);

    // CTRL: start=1, data_dir=0, has_addr=0, data_mode=00, dummy=0
    axi_write(dut, tfp, REG_CTRL, make_ctrl(true, false, false, 0, 0));

    wait_done(dut, tfp, "WREN command");

    delay(dut, tfp, 10);

    // =================================================================
    // TEST 2: Page program (0x02) — format: 1-1-1, write 16 bytes
    //   Push 4 x 32-bit words into RX FIFO before starting
    // =================================================================
    std::cout << "\n[TEST 2] Page program (0x02): write 16 bytes\n";

    // Pre-fill RX FIFO with 4 words = 16 bytes
    uint32_t write_data[4] = {0x4030BBAA, 0x80706050, 0x04030201, 0x08070605};
    for (int i = 0; i < 4; i++) {
        push_rx_fifo(dut, tfp, write_data[i]);
        std::cout << "  pushed word[" << i << "] = 0x" << std::hex << write_data[i] << "\n";
    }

    axi_write(dut, tfp, REG_INSTR,    0x02);
    axi_write(dut, tfp, REG_ADDR,     0x00AABB0C);
    axi_write(dut, tfp, REG_DATA_CNT, 15);   // 16 bytes (0-indexed)

    // CTRL: start=1, data_dir=1 (write), has_addr=1, data_mode=01, dummy=0
    axi_write(dut, tfp, REG_CTRL, make_ctrl(true, true, true, 1, 0));

    wait_done(dut, tfp, "Page program", 2000);

    delay(dut, tfp, 10);

    // =================================================================
    // TEST 3: Sector erase (0x21) — format: 1-1-0
    //   instr=0x21, has address, no data
    // =================================================================
    std::cout << "\n[TEST 3] Sector erase (0x21): address only\n";

    axi_write(dut, tfp, REG_INSTR,    0x21);
    axi_write(dut, tfp, REG_ADDR,     0x00AABB0C);
    axi_write(dut, tfp, REG_DATA_CNT, 0x00);

    // CTRL: start=1, data_dir=0, has_addr=1, data_mode=00, dummy=0
    axi_write(dut, tfp, REG_CTRL, make_ctrl(true, false, true, 0, 0));

    wait_done(dut, tfp, "Sector erase", 1000);

    delay(dut, tfp, 10);

    // =================================================================
    // TEST 4: Write Status Register (0x01) — format: 1-0-1, write 1 byte
    //   Push 1 byte (0xAB) into RX FIFO
    // =================================================================
    std::cout << "\n[TEST 4] Write Status Register (0x01): 1 byte\n";

    push_rx_fifo(dut, tfp, 0x000000AB);

    delay(dut, tfp, 5);

    axi_write(dut, tfp, REG_INSTR,    0x01);
    axi_write(dut, tfp, REG_ADDR,     0x00000000);
    axi_write(dut, tfp, REG_DATA_CNT, 0x00);   // 1 byte

    // CTRL: start=1, data_dir=1 (write), has_addr=0, data_mode=01, dummy=0
    axi_write(dut, tfp, REG_CTRL, make_ctrl(true, true, false, 1, 0));

    wait_done(dut, tfp, "Write Status Register", 1000);

    delay(dut, tfp, 10);

    // =================================================================
    // TEST 5: Fast Read (0x0B) — format: 1-1-1 with 8 dummy cycles
    //   Read 12 bytes, toggle miso_i to simulate NOR output
    // =================================================================
    std::cout << "\n[TEST 5] Fast Read (0x0B): 12 bytes with 8 dummy cycles\n";

    axi_write(dut, tfp, REG_INSTR,    0x0B);
    axi_write(dut, tfp, REG_ADDR,     0x00AABB0C);
    axi_write(dut, tfp, REG_DATA_CNT, 11);   // 12 bytes (0-indexed)

    // CTRL: start=1, data_dir=0 (read), has_addr=1, data_mode=01, dummy=8
    axi_write(dut, tfp, REG_CTRL, make_ctrl(true, false, true, 1, 8));

    // Wait for address + dummy phase to finish before toggling MISO
    delay(dut, tfp, 180);

    // Toggle MISO to simulate flash data output (same pattern as original TB)
    for (int i = 0; i < 60; i++) {
        dut->miso_i = i % 2;
        delay(dut, tfp, 5);
    }

    delay(dut, tfp, 200);

    wait_done(dut, tfp, "Fast Read", 100);

    delay(dut, tfp, 10);

    // Read back 3 words from TX FIFO (12 bytes = 3 x 32-bit words)
    std::cout << "  Reading 3 words from TX FIFO:\n";
    for (int i = 0; i < 3; i++) {
        uint32_t word = pull_tx_fifo(dut, tfp);
        std::cout << "  word[" << i << "] = 0x" << std::hex << word << "\n";
    }

    delay(dut, tfp, 10);

    // =================================================================
    // TEST 6: Read Status Register (0x05) — format: 1-0-1
    //   No address, no dummy, read 1 byte
    // =================================================================
    std::cout << "\n[TEST 6] Read Status Register (0x05): 1 byte\n";

    axi_write(dut, tfp, REG_INSTR,    0x05);
    axi_write(dut, tfp, REG_ADDR,     0x00000000);
    axi_write(dut, tfp, REG_DATA_CNT, 0x00);   // 1 byte

    // CTRL: start=1, data_dir=0 (read), has_addr=0, data_mode=01, dummy=0
    axi_write(dut, tfp, REG_CTRL, make_ctrl(true, false, false, 1, 0));

    // Let the command byte go out before toggling MISO
    delay(dut, tfp, 20);

    // Toggle MISO (same as original testbench)
    for (int i = 0; i < 60; i++) {
        dut->miso_i = i % 2;
        delay(dut, tfp, 5);
    }

    delay(dut, tfp, 100);

    wait_done(dut, tfp, "Read Status Register", 100);

    // Read back 1 byte from TX FIFO
    uint32_t status_byte = pull_tx_fifo(dut, tfp);
    std::cout << "  status byte = 0x" << std::hex << status_byte << "\n";
    printf("  in binary: 0b%b\n", status_byte);

    delay(dut, tfp, 10);

    // =================================================================
    // TEST 7: Second Read Status Register back-to-back (regression)
    // =================================================================
    std::cout << "\n[TEST 7] Read Status Register (0x05): back-to-back\n";

    axi_write(dut, tfp, REG_INSTR,    0x05);
    axi_write(dut, tfp, REG_DATA_CNT, 0x00);
    axi_write(dut, tfp, REG_ADDR,     0x00000000);

    axi_write(dut, tfp, REG_CTRL, make_ctrl(true, false, false, 1, 0));

    delay(dut, tfp, 100);

    wait_done(dut, tfp, "Read Status Register (back-to-back)", 100);

    delay(dut, tfp, 20);

    std::cout << "\nAll tests finished.\n";

    dut->final();
    tfp->close();
    delete dut;
    return 0;
}