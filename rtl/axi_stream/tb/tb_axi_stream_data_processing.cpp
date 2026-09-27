#include "Vaxi_stream_data_processing.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <cassert>

vluint64_t sim_time = 0;

void tick(Vaxi_stream_data_processing *dut, VerilatedVcdC* tfp) {
    dut->clk_i = 1;
    dut->eval();
    tfp->dump(sim_time++);

    dut->clk_i = 0;
    dut->eval();
    tfp->dump(sim_time++);
}

void delay(Vaxi_stream_data_processing *dut, VerilatedVcdC* tfp, uint32_t count) {
    for (int i = 0; i < count; i++) {
        tick(dut, tfp);
    }
}

// -------------------------------------------------
// MAIN
// -------------------------------------------------
int main(int argc, char **argv) {

    Verilated::commandArgs(argc, argv);

    Vaxi_stream_data_processing *dut = new Vaxi_stream_data_processing;

    VerilatedVcdC* tfp = new VerilatedVcdC;
    Verilated::traceEverOn(true);
    dut->trace(tfp, 99);
    tfp->open("waveform.vcd");

    // Initialize signals
    dut->rst_n = 0;

    delay(dut, tfp, 5);

    dut->rst_n = 1;

    delay(dut, tfp, 5);

    dut->S_AXIS_TSTRB = 0b1111; // no byte masking

    /*
        test 1: send data into the axi stream slave
    */
    dut->S_AXIS_TVALID = 1;
    tick(dut, tfp);
    for (uint32_t i = 1; i < 20; i++) {
        // should check TREADY here
        dut->S_AXIS_TDATA = i;
        tick(dut, tfp);
        // wait for S_AXIS_TREADY and decide to send or pause at the same cycle
        if (!dut->S_AXIS_TREADY) {
            printf("data input full, dont send anymore\n");
            break;
        }
    }

    dut->S_AXIS_TVALID = 0; 
    delay(dut, tfp, 40);
    
    /*
        test 2: send data into the axi stream slave again
    */

    dut->S_AXIS_TVALID = 1; 
    tick(dut, tfp);
    for (uint32_t i = 17; i < 27; i++) {
        // should check TREADY here
        dut->S_AXIS_TDATA = i;
        tick(dut, tfp);
        // wait for S_AXIS_TREADY and decide to send or pause at the same cycle
        if (!dut->S_AXIS_TREADY) {
            printf("data input full, dont send anymore\n");
            break;
        }
    }

    dut->S_AXIS_TVALID = 0; 
    
    delay(dut, tfp, 20);

    /*
        test 3: read out processed data from axi stream master
    */

    // read out now
    dut->M_AXIS_TREADY = 1;

    while (1) {
        tick(dut, tfp);
        
        // tlast data is the last data, so still valid data
        printf("value after processing is 0x%x\n", dut->M_AXIS_TDATA);

        if (dut->M_AXIS_TLAST) {
            break;
        }        
    }

    dut->M_AXIS_TREADY = 0;

    delay(dut, tfp, 20);

    /*
        test 4: try everything again
    */

    dut->S_AXIS_TVALID = 1; 
    tick(dut, tfp);

    for (uint32_t i = 33; i < 50; i++) {
        // should check TREADY here
        dut->S_AXIS_TDATA = i;
        tick(dut, tfp);
        // wait for S_AXIS_TREADY and decide to send or pause at the same cycle
        if (!dut->S_AXIS_TREADY) {
            printf("data input full, dont send anymore\n");
            break;
        }
    }

    dut->S_AXIS_TVALID = 0; 
    
    delay(dut, tfp, 20);

    // read out now
    dut->M_AXIS_TREADY = 1;

    while (1) {
        tick(dut, tfp);
        
        // tlast data is the last data, so still valid data
        printf("value after processing is 0x%x\n", dut->M_AXIS_TDATA);

        if (dut->M_AXIS_TLAST) {
            break;
        }        
    }

    dut->M_AXIS_TREADY = 0;

    delay(dut, tfp, 20);


    std::cout << "finished test\n";

    // Finish
    dut->final();
    tfp->close();
    delete dut;
    return 0;
}
