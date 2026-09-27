#include "Vaxi_stream_master.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <cassert>

vluint64_t sim_time = 0;

void tick(Vaxi_stream_master *dut, VerilatedVcdC* tfp) {
    dut->M_AXIS_ACLK = 1;
    dut->eval();
    tfp->dump(sim_time++);

    dut->M_AXIS_ACLK = 0;
    dut->eval();
    tfp->dump(sim_time++);
}

void delay(Vaxi_stream_master *dut, VerilatedVcdC* tfp, uint32_t count) {
    for (int i = 0; i < count; i++) {
        tick(dut, tfp);
    }
}

// -------------------------------------------------
// MAIN
// -------------------------------------------------
int main(int argc, char **argv) {

    Verilated::commandArgs(argc, argv);

    Vaxi_stream_master *dut = new Vaxi_stream_master;

    VerilatedVcdC* tfp = new VerilatedVcdC;
    Verilated::traceEverOn(true);
    dut->trace(tfp, 99);
    tfp->open("waveform.vcd");

    // Initialize signals
    dut->M_AXIS_ARESETN = 0;

    delay(dut, tfp, 5);
    // streaming out 1 during reset, but doesnt matter because it dont show tvalid

    dut->M_AXIS_ARESETN = 1;

    delay(dut, tfp, 40);
    

    dut->M_AXIS_TREADY = 1;

    while(1) {
        tick(dut, tfp);
        
        // tlast data is the last data, so still valid data
        printf("value is 0x%x\n", dut->M_AXIS_TDATA);

        if (dut->M_AXIS_TLAST) {
            break;
        }
        
    }
    dut->M_AXIS_TREADY = 0;

    delay(dut, tfp, 40);



    std::cout << "finished test\n";

    // Finish
    dut->final();
    tfp->close();
    delete dut;
    return 0;
}
