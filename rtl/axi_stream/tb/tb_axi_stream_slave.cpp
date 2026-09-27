#include "Vaxi_stream_slave.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <cassert>

vluint64_t sim_time = 0;

void tick(Vaxi_stream_slave *dut, VerilatedVcdC* tfp) {
    dut->S_AXIS_ACLK = 1;
    dut->eval();
    tfp->dump(sim_time++);

    dut->S_AXIS_ACLK = 0;
    dut->eval();
    tfp->dump(sim_time++);
}

void delay(Vaxi_stream_slave *dut, VerilatedVcdC* tfp, uint32_t count) {
    for (int i = 0; i < count; i++) {
        tick(dut, tfp);
    }
}

// -------------------------------------------------
// MAIN
// -------------------------------------------------
int main(int argc, char **argv) {

    Verilated::commandArgs(argc, argv);

    Vaxi_stream_slave *dut = new Vaxi_stream_slave;

    VerilatedVcdC* tfp = new VerilatedVcdC;
    Verilated::traceEverOn(true);
    dut->trace(tfp, 99);
    tfp->open("waveform.vcd");

    // Initialize signals
    dut->S_AXIS_ARESETN = 0;

    delay(dut, tfp, 5);

    dut->S_AXIS_ARESETN = 1;

    delay(dut, tfp, 5);

    dut->S_AXIS_TSTRB = 0b1111; // no byte masking

    dut->S_AXIS_TVALID = 1;

    tick(dut, tfp);

    for (uint32_t i = 10; i < 15; i++) {
        dut->S_AXIS_TDATA = i;
        tick(dut, tfp);
        // wait for S_AXIS_TREADY and decide to send or pause at the same cycle

    }

    dut->S_AXIS_TVALID = 0; 
    delay(dut, tfp, 5);


    std::cout << "finished test\n";

    // Finish
    dut->final();
    tfp->close();
    delete dut;
    return 0;
}
