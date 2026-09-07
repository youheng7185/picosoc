#include "Vaxil_ram.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <cassert>

vluint64_t sim_time = 0;

void tick(Vaxil_ram *dut, VerilatedVcdC* tfp) {
    dut->S_AXI_ACLK = 0;
    dut->eval();
    tfp->dump(sim_time++);

    dut->S_AXI_ACLK = 1;
    dut->eval();
    tfp->dump(sim_time++);
}

// -------------------------------------------------
// AXI WRITE
// -------------------------------------------------
void axi_write(Vaxil_ram *dut, VerilatedVcdC* tfp,
               uint32_t addr, uint32_t data)
{
    // Setup write address + data
    dut->S_AXI_AWADDR  = addr;
    dut->S_AXI_AWVALID = 1;

    dut->S_AXI_WDATA  = data;
    dut->S_AXI_WSTRB  = 0xF;
    dut->S_AXI_WVALID = 1;

    dut->S_AXI_BREADY = 1;

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
uint32_t axi_read(Vaxil_ram *dut, VerilatedVcdC* tfp,
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


void delay(Vaxil_ram *dut, VerilatedVcdC* tfp, uint32_t count) {
    for (int i = 0; i < count; i++) {
        tick(dut, tfp);
    }
}

// -------------------------------------------------
// MAIN
// -------------------------------------------------
int main(int argc, char **argv) {

    Verilated::commandArgs(argc, argv);

    Vaxil_ram *dut = new Vaxil_ram;

    VerilatedVcdC* tfp = new VerilatedVcdC;
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

    // Reset sequence
    for (int i = 0; i < 5; i++)
        tick(dut, tfp);

    dut->S_AXI_ARESETN = 1;

    for (int i = 0; i < 5; i++)
        tick(dut, tfp);

    std::cout << "Starting AXI GPIO test\n";

    for (uint32_t i = 0; i < 8192; i++) {
        axi_write(dut, tfp, (i << 2), (i | i << 16));
    }

    uint32_t data_read;

    for (uint32_t i = 0; i < 8192; i++) {
        data_read = axi_read(dut, tfp, (i <<  2));
        if (data_read != (i | i << 16)) {
            std::cout << "read error\n";
        }
    }

    std::cout << "Write done\n";


    // Finish
    dut->final();
    tfp->close();
    delete dut;
    return 0;
}