#include "Vpicosoc.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <cassert>

vluint64_t sim_time = 0;

void tick(Vpicosoc *dut, VerilatedVcdC* tfp) {
    dut->clk_i = 0;
    dut->eval();
    tfp->dump(sim_time++);

    dut->clk_i = 1;
    dut->eval();
    tfp->dump(sim_time++);
}


void delay(Vpicosoc *dut, VerilatedVcdC* tfp, uint32_t count) {
    for (int i = 0; i < count; i++) {
        tick(dut, tfp);
    }
}

// -------------------------------------------------
// MAIN
// -------------------------------------------------
int main(int argc, char **argv) {

    Verilated::commandArgs(argc, argv);

    Vpicosoc *dut = new Vpicosoc;

    VerilatedVcdC* tfp = new VerilatedVcdC;
    Verilated::traceEverOn(true);
    dut->trace(tfp, 99);
    tfp->open("waveform.vcd");

    // dut->rst_n = 0;

    delay(dut, tfp, 10);
    // dut->rst_n = 1;
    dut->uart_rx_i = 1;
    delay(dut, tfp, 50000);

    // Finish
    dut->final();
    tfp->close();
    delete dut;
    return 0;
}