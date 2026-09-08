#include "Vqspi_nor_master.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <cassert>

vluint64_t sim_time = 0;

void tick(Vqspi_nor_master *dut, VerilatedVcdC* tfp) {
    dut->clk_i = 0;
    dut->eval();
    tfp->dump(sim_time++);

    dut->clk_i = 1;
    dut->eval();
    tfp->dump(sim_time++);
}

void delay(Vqspi_nor_master *dut, VerilatedVcdC* tfp, uint32_t count) {
    for (int i = 0; i < count; i++) {
        tick(dut, tfp);
    }
}

void waiting_spi_falling_edge(Vqspi_nor_master *dut, VerilatedVcdC* tfp) {
    while (dut->spi_clk_o == 0) {
        tick(dut, tfp);
    }

    while (dut->spi_clk_o == 1) {
        tick(dut, tfp);
    }
}

// -------------------------------------------------
// MAIN
// -------------------------------------------------
int main(int argc, char **argv) {

    Verilated::commandArgs(argc, argv);

    Vqspi_nor_master *dut = new Vqspi_nor_master;

    VerilatedVcdC* tfp = new VerilatedVcdC;
    Verilated::traceEverOn(true);
    dut->trace(tfp, 99);
    tfp->open("waveform.vcd");

    // Initialize signals
    dut->rst_n = 0;

    delay(dut, tfp, 5);

    dut->rst_n = 1;

    delay(dut, tfp, 5);

    /*
        command only, 1-0-0
    */
    dut->instr_i = 0x06;
    dut->start_i = 1;

    delay(dut, tfp, 60);
    dut->start_i = 0;

    /*
        page program, 1-1-1
    */
    dut->rx_fifo_data_wr_en = 1;
    uint32_t data2[4] = {0x4030BBAA, 0x80706050, 0x04030201, 0x08070605};

    for (int i = 0; i < 4; i++) {
        dut->rx_fifo_data_din = data2[i];
        tick(dut, tfp);
    }

    dut->rx_fifo_data_wr_en = 0;

    tick(dut, tfp);
    dut->instr_i = 0x02; // fixme, its 0x02 actually
    dut->data_mode_i = 1;
    dut->data_cnt_i = 15; // 16 bytes
    dut->has_address_i = 1;
    dut->data_dir_i = 1;    
    dut->addr_i = 0x00AABB0C;
    dut->start_i = 1;

    delay(dut, tfp, 700);
    dut->start_i = 0;
    tick(dut, tfp);

    /*
        sector erase 1-1-0
    */
    dut->instr_i = 0x21;
    dut->data_mode_i = 0; // no data to transfer
    dut->has_address_i = 1;
    dut->addr_i = 0x00AABB0C;
    dut->start_i = 1;

    delay(dut, tfp, 200);
    dut->start_i = 0;
    delay(dut, tfp, 10);

    /*
        write status register 1-0-1
    */
    dut->rx_fifo_data_wr_en = 1;
    dut->rx_fifo_data_din = 0x000000AB;
    tick(dut, tfp);
    dut->rx_fifo_data_wr_en = 0;
    delay(dut, tfp, 10);

    dut->instr_i = 0x01;
    dut->has_address_i = 0;
    dut->addr_i = 0x00;
    dut->data_dir_i = 1; // write
    dut->data_mode_i = 1;
    dut->data_cnt_i = 0x00; // 1 byte
    dut->start_i = 1;
    delay(dut, tfp, 300);
    dut->start_i = 0;
    delay(dut, tfp, 10);

    /*
        page read 1-1-1, has dummy cycle
    */
    dut->instr_i = 0x0B; // fast read
    dut->has_address_i = 1;
    dut->addr_i = 0x00AABB0C;
    dut->dummy_cnt_i = 8; // 8 dummy cycle
    dut->data_mode_i = 0b01; // has data
    dut->data_dir_i = 0; // read data
    // dut->data_cnt_i = 11; // 12 bytes
    dut->data_cnt_i = 9; // 10 bytes, not 4 byte aligned for testing
    dut->start_i = 1;

    for (int i = 0; i < 38; i++) {
        waiting_spi_falling_edge(dut, tfp);
    }

    uint8_t data_input[12] = {0xAA, 0x0B, 0x0C, 0x0D, 0xAA, 0x0B, 0x0C, 0x0D, 0xAA, 0x0B, 0x0C, 0x0D};

    for (int j = 0; j < 10; j++) {
        for (int i = 7; i >= 0; i--) {
            waiting_spi_falling_edge(dut, tfp);
            dut->miso_i = (data_input[j] >> i) & 1;
        }
    }

    delay(dut, tfp, 400);

    dut->start_i = 0;
    delay(dut, tfp, 10);

    dut->tx_fifo_rd_en = 1;
    for (int i = 0; i < 4; i++) {
        tick(dut, tfp);
        std::cout << "tick out the data: " << std::hex << dut->tx_fifo_data_dout << std::endl;
    }
    dut->tx_fifo_rd_en = 0;    
    tick(dut, tfp);

    /*
        read registers or status 1-0-1
    */
    dut->instr_i = 0x05; // fast read
    dut->has_address_i = 0;
    dut->dummy_cnt_i = 0; // 0 dummy cycle
    dut->data_mode_i = 0b01; // has data
    dut->data_dir_i = 0; // read data
    dut->data_cnt_i = 0; // 1 bytes
    dut->start_i = 1;

    delay(dut, tfp, 20);

    for (int i = 0; i < 60; i++) {
        dut->miso_i = i % 2;
        delay(dut, tfp, 5);
    }

    delay(dut, tfp, 100);
    dut->tx_fifo_rd_en = 1;
    tick(dut, tfp);
    std::cout << "tick out the data: " << std::hex << dut->tx_fifo_data_dout << std::endl;
    printf("in binary: 0b%b\n", dut->tx_fifo_data_dout);
    dut->tx_fifo_rd_en = 0;  
    tick(dut, tfp);
    dut->start_i = 0;
    delay(dut, tfp, 10);

    dut->start_i = 1;
    dut->instr_i = 0x05;
    dut->data_mode_i = 0b01;
    dut->data_cnt_i = 0;
    dut->has_address_i = 0;
    dut->data_dir_i = 0;
    delay(dut, tfp, 100);

    // dut->start_i = 1;
    // dut->instr_i = 0x05;
    // dut->data_mode_i = 0b01;
    // dut->data_cnt_i = 0;
    // dut->has_address_i = 1;
    
    // dut->data_dir_i = 0;
    // delay(dut, tfp, 300);

    std::cout << "finished test\n";

    // Finish
    dut->final();
    tfp->close();
    delete dut;
    return 0;
}
