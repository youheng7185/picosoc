#include "Vaxi_mdio.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <cassert>

vluint64_t sim_time = 0;

void tick(Vaxi_mdio *dut, VerilatedVcdC* tfp) {
    dut->S_AXI_ACLK = 0;
    dut->eval();
    tfp->dump(sim_time++);

    dut->S_AXI_ACLK = 1;
    dut->eval();
    tfp->dump(sim_time++);
}

void delay(Vaxi_mdio *dut, VerilatedVcdC* tfp, uint32_t count)
{
    for (int i = 0; i < count; i++)
        tick(dut, tfp);
}


// -------------------------------------------------
// AXI WRITE
// -------------------------------------------------
void axi_write(Vaxi_mdio *dut, VerilatedVcdC* tfp,
               uint32_t addr, uint32_t data)
{
    dut->S_AXI_AWADDR  = addr;
    dut->S_AXI_AWVALID = 1;

    dut->S_AXI_WDATA  = data;
    dut->S_AXI_WSTRB  = 0xF;
    dut->S_AXI_WVALID = 1;

    dut->S_AXI_BREADY = 1;


    while (!dut->S_AXI_AWREADY)
        tick(dut, tfp);

    tick(dut, tfp);

    dut->S_AXI_AWVALID = 0;
    dut->S_AXI_WVALID  = 0;


    while (!dut->S_AXI_BVALID)
        tick(dut, tfp);

    tick(dut, tfp);

    dut->S_AXI_BREADY = 0;
}


// -------------------------------------------------
// AXI READ
// -------------------------------------------------
uint32_t axi_read(Vaxi_mdio *dut, VerilatedVcdC* tfp,
                  uint32_t addr)
{
    dut->S_AXI_ARADDR  = addr;
    dut->S_AXI_ARVALID = 1;

    dut->S_AXI_RREADY = 1;


    while (!dut->S_AXI_ARREADY)
        tick(dut, tfp);

    tick(dut, tfp);

    dut->S_AXI_ARVALID = 0;


    while (!dut->S_AXI_RVALID)
        tick(dut, tfp);


    uint32_t data = dut->S_AXI_RDATA;


    tick(dut, tfp);

    dut->S_AXI_RREADY = 0;


    return data;
}


// -------------------------------------------------
// MAIN
// -------------------------------------------------
int main(int argc, char **argv)
{
    Verilated::commandArgs(argc, argv);

    Vaxi_mdio *dut = new Vaxi_mdio;


    VerilatedVcdC* tfp = new VerilatedVcdC;
    Verilated::traceEverOn(true);
    dut->trace(tfp, 99);
    tfp->open("waveform.vcd");


    // init

    dut->S_AXI_ARESETN = 0;

    dut->S_AXI_AWVALID = 0;
    dut->S_AXI_WVALID  = 0;
    dut->S_AXI_BREADY  = 0;

    dut->S_AXI_ARVALID = 0;
    dut->S_AXI_RREADY  = 0;

    // fake mdio input
    dut->mdio_i = 0;


    delay(dut, tfp, 5);


    dut->S_AXI_ARESETN = 1;


    delay(dut, tfp, 5);



    std::cout << "Starting MDIO AXI test\n";


    //--------------------------------------------------
    // WRITE TRANSACTION
    //--------------------------------------------------

    uint32_t phy = 0b10100;
    uint32_t reg = 0b10110;

    uint32_t ctrl =
        (phy & 0x1F) |
        ((reg & 0x1F) << 5) |
        (0xABCD << 10);


    // rw=0
    axi_write(dut, tfp, 0x00, 0x0);

    // phy/reg/data
    axi_write(dut, tfp, 0x04, ctrl);


    // start pulse
    axi_write(dut, tfp, 0x00, 0x1);


    delay(dut, tfp, 5);


    // clear start
    axi_write(dut, tfp, 0x00, 0x0);



    //--------------------------------------------------
    // wait done
    //--------------------------------------------------

    uint32_t status;

    do {
        status = axi_read(dut, tfp, 0x00);
    } while (!(status & (1<<2)));


    std::cout << "MDIO write done\n";



    //--------------------------------------------------
    // READ TRANSACTION
    //--------------------------------------------------

    phy = 0b10110;
    reg = 0b10100;


    ctrl =
        (phy & 0x1F) |
        ((reg & 0x1F) << 5);


    // rw=1
    axi_write(dut, tfp, 0x00, 0x2);


    // phy/reg
    axi_write(dut, tfp, 0x04, ctrl);


    // start
    axi_write(dut, tfp, 0x00, 0x3);


    delay(dut, tfp, 5);


    // clear start
    axi_write(dut, tfp, 0x00, 0x2);



    //--------------------------------------------------
    // fake MDIO response
    //--------------------------------------------------

    dut->mdio_i = 1;


    do {
        status = axi_read(dut, tfp, 0x00);
    } while (!(status & (1<<2)));



    uint32_t read_value = axi_read(dut, tfp, 0x08);


    std::cout 
        << "Read value = 0x"
        << std::hex
        << read_value
        << "\n";



    std::cout << "finished test\n";


    dut->final();

    tfp->close();

    delete dut;

    return 0;
}