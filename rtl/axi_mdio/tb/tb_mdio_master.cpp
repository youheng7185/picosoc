#include "Vmdio_master.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <cassert>

vluint64_t sim_time = 0;

void tick(Vmdio_master *dut, VerilatedVcdC* tfp) {
    dut->clk_i = 0;
    dut->eval();
    tfp->dump(sim_time++);

    dut->clk_i = 1;
    dut->eval();
    tfp->dump(sim_time++);
}

void delay(Vmdio_master *dut, VerilatedVcdC* tfp, uint32_t count) {
    for (int i = 0; i < count; i++) {
        tick(dut, tfp);
    }
}

void phy_respond_read(Vmdio_master *dut, VerilatedVcdC* tfp, uint16_t data) {
    uint8_t prev_mdc = dut->mdc_o;
    int mdc_rise_count = 0;
    bool found_start = false;
    int consecutive_ones = 0;
    uint8_t prev_mdio = 0;

    std::cout << "Waiting for preamble + start 01 pattern...\n";

    // Phase 1: detect start pattern "01"
    // count rising edges, look for transition 1->0 on mdio (start bit 0)
    // then confirm next bit is 1
    while (!found_start) {
        tick(dut, tfp);
        uint8_t curr_mdc  = dut->mdc_o;
        uint8_t curr_mdio = dut->mdio_o;

        // sample on rising edge
        if (prev_mdc == 0 && curr_mdc == 1) {
            mdc_rise_count++;

            if (curr_mdio == 1) {
                consecutive_ones++;
            }

            // after preamble (32 ones), look for 0 then 1
            if (consecutive_ones >= 32) {
                if (prev_mdio == 1 && curr_mdio == 0) {
                    // found the 0 of start delimiter "01"
                    std::cout << "  Found start bit 0 at rise " << mdc_rise_count << "\n";
                } else if (prev_mdio == 0 && curr_mdio == 1) {
                    // found the 1 of start delimiter "01"
                    std::cout << "  Found start bit 1 at rise " << mdc_rise_count << "\n";
                    // this rising edge is pulse 1 (start bit 0 was pulse 0)
                    // data begins at rising edge 16 from here:
                    // opcode(2) + phy_addr(5) + reg_addr(5) + TA(2) = 14 more pulses
                    // so we need 14 more rising edges before we start driving
                    found_start = true;
                }
            }
            prev_mdio = curr_mdio;
        }

        prev_mdc = curr_mdc;
    }

    // Phase 2: count 14 more rising edges (opcode + phy_addr + reg_addr + TA)
    // then start driving data on falling edges
    std::cout << "  Counting 14 more pulses (opcode+addr+TA)...\n";
    int skip_count = 0;
    prev_mdc = dut->mdc_o;

    while (skip_count < 13) { // 13 waveform is correct
        tick(dut, tfp);
        uint8_t curr_mdc = dut->mdc_o;

        if (prev_mdc == 0 && curr_mdc == 1) {
            skip_count++;
            std::cout << "  Skip pulse " << skip_count << "\n";
        }

        prev_mdc = curr_mdc;
    }

    // Phase 3: drive TA (2 bits) then 16 data bits MSB first on falling edges
    std::cout << "  Driving TA then shifting in 0x" << std::hex << data << std::dec << "\n";
    
    int ta_sent = 0;
    int bits_sent = 0;
    prev_mdc = dut->mdc_o;

    while (bits_sent < 16) {
        tick(dut, tfp);
        uint8_t curr_mdc = dut->mdc_o;
 
        if (prev_mdc == 1 && curr_mdc == 0) {
            if (ta_sent == 0) {
                // TA bit 1: PHY drives 0
                dut->mdio_i = 0;
                std::cout << "  TA bit 1 = 0\n";
                ta_sent++;
            } else if (ta_sent == 1) {
                // TA bit 0: float/high-z, drive 1 in simulation
                // dut->mdio_i = 1;
                // std::cout << "  TA bit 0 = 1 (float)\n";
                // ta_sent++;
                int bit_index = 15 - bits_sent;
                dut->mdio_i = (data >> bit_index) & 1;
                std::cout << "  bit[" << bit_index << "] = " << (int)dut->mdio_i << "\n";
                bits_sent++;
            } else {
                // actual data bits
                
            }
        }
 
        prev_mdc = curr_mdc;
    }

    std::cout << "  All 16 bits shifted in\n";
}

// -------------------------------------------------
// MAIN
// -------------------------------------------------
int main(int argc, char **argv) {

    Verilated::commandArgs(argc, argv);

    Vmdio_master *dut = new Vmdio_master;

    VerilatedVcdC* tfp = new VerilatedVcdC;
    Verilated::traceEverOn(true);
    dut->trace(tfp, 99);
    tfp->open("waveform.vcd");

    // Initialize signals
    dut->rst_n = 0;

    delay(dut, tfp, 5);

    dut->rst_n = 1;

    delay(dut, tfp, 5);

    // write first

    dut->rw_i = 0;
    dut->phy_addr_i = 0b10100;
    dut->reg_addr_i = 0b10110;
    dut->reg_value_write_i = 0xABCD; // 16 bit only
    delay(dut, tfp, 5);
    dut->start_i = 1; // level trigger

    delay(dut, tfp, 5);
    dut->start_i = 0;

    delay(dut, tfp, 10000);


    // read

    dut->mdio_i = 1; // fake 1

    dut->rw_i = 1;
    dut->phy_addr_i = 0b10110;
    dut->reg_addr_i = 0b10100;
    delay(dut, tfp, 5);
    dut->start_i = 1; // level trigger

    delay(dut, tfp, 5);
    dut->start_i = 0;

    uint16_t phy_data = 0x3100;
    phy_respond_read(dut, tfp, phy_data);

    delay(dut, tfp, 10000);
    std::cout << "Got:      0x" << std::hex << (int)dut->reg_value_read_o << "\n";


    std::cout << "finished test\n";

    // Finish
    dut->final();
    tfp->close();
    delete dut;
    return 0;
}