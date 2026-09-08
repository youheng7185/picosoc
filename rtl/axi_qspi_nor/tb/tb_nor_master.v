/*
    claude written testbench, using winbond flash model
*/

`timescale 1ns/1ps

module tb_qspi_nor;

    // -------------------------------------------------------------------------
    // Clock & reset
    // -------------------------------------------------------------------------
    reg clk_i;
    reg rst_n;

    initial clk_i = 0;
    always #10 clk_i = ~clk_i; // 50MHz

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg         start_i;
    reg  [7:0]  instr_i;
    reg  [4:0]  dummy_cnt_i;
    reg  [1:0]  data_mode_i;
    reg  [7:0]  data_cnt_i;
    reg         has_address_i;
    reg         data_dir_i;
    reg  [31:0] addr_i;

    // tx fifo (read data out to testbench)
    reg         tx_fifo_rd_en;
    wire [31:0] tx_fifo_data_dout;
    wire        tx_fifo_data_full;
    wire        tx_fifo_data_empty;

    // rx fifo (write data in from testbench)
    reg         rx_fifo_data_wr_en;
    reg  [31:0] rx_fifo_data_din;
    wire        rx_fifo_data_full;
    wire        rx_fifo_data_empty;

    wire        done_o;
    wire        cs_n_o;
    wire        mosi_o;
    wire        spi_clk_o;
    wire        miso_i;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    qspi_nor_master #(.DIV(4)) u_dut (
        .clk_i              (clk_i),
        .rst_n              (rst_n),
        .cs_n_o             (cs_n_o),
        .miso_i             (miso_i),
        .mosi_o             (mosi_o),
        .spi_clk_o          (spi_clk_o),
        .start_i            (start_i),
        .done_o             (done_o),
        .instr_i            (instr_i),
        .dummy_cnt_i        (dummy_cnt_i),
        .data_mode_i        (data_mode_i),
        .data_cnt_i         (data_cnt_i),
        .has_address_i      (has_address_i),
        .data_dir_i         (data_dir_i),
        .addr_i             (addr_i),
        .tx_fifo_rd_en      (tx_fifo_rd_en),
        .tx_fifo_data_dout  (tx_fifo_data_dout),
        .tx_fifo_data_full  (tx_fifo_data_full),
        .tx_fifo_data_empty (tx_fifo_data_empty),
        .rx_fifo_data_wr_en (rx_fifo_data_wr_en),
        .rx_fifo_data_din   (rx_fifo_data_din),
        .rx_fifo_data_full  (rx_fifo_data_full),
        .rx_fifo_data_empty (rx_fifo_data_empty)
    );

    // -------------------------------------------------------------------------
    // Flash model
    // -------------------------------------------------------------------------
    wire wpn_tie   = 1'b1;
    wire holdn_tie = 1'b1;
    
    W25Q128JVxIM u_flash (
        .CSn   (cs_n_o),
        .CLK   (spi_clk_o),
        .DIO   (mosi_o),
        .DO    (miso_i),
        .WPn   (wpn_tie),
        .HOLDn (holdn_tie)
    );

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------
    task do_ticks;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk_i);
        end
    endtask

    task wait_done;
        begin
            @(posedge done_o);
            @(posedge clk_i);
            start_i = 0;
            do_ticks(10);
        end
    endtask

    task push_rx_fifo;
        input [31:0] data;
        begin
            @(posedge clk_i);
            rx_fifo_data_wr_en = 1;
            rx_fifo_data_din   = data;
            @(posedge clk_i);
            rx_fifo_data_wr_en = 0;
        end
    endtask

//    task pop_tx_fifo;
//        output [31:0] data;
//        reg [31:0] raw;
//        begin
//            @(posedge clk_i);
//            tx_fifo_rd_en = 1;
//            @(posedge clk_i);
//            raw = tx_fifo_data_dout;
//            tx_fifo_rd_en = 0;
//            // byte swap: flash sends MSB first, we accumulate LSB first in fifo
//            data = {raw[7:0], raw[15:8], raw[23:16], raw[31:24]};
//        end
//    endtask
    
    task pop_tx_fifo;
        output [31:0] data;
        begin
            @(posedge clk_i);
            tx_fifo_rd_en = 1;
            @(posedge clk_i);
            data = tx_fifo_data_dout;
            tx_fifo_rd_en = 0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Default signal state
    // -------------------------------------------------------------------------
    task defaults;
        begin
            start_i            = 0;
            instr_i            = 0;
            dummy_cnt_i        = 0;
            data_mode_i        = 2'b00;
            data_cnt_i         = 0;
            has_address_i      = 0;
            data_dir_i         = 0;
            addr_i             = 0;
            tx_fifo_rd_en      = 0;
            rx_fifo_data_wr_en = 0;
            rx_fifo_data_din   = 0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Common SPI operations
    // -------------------------------------------------------------------------

    // WREN - Write Enable (0x06), cmd only
    task op_wren;
        begin
            $display("[%0t] WREN", $time);
            instr_i       = 8'h06;
            has_address_i = 0;
            data_mode_i   = 2'b00;
            data_dir_i    = 0;
            dummy_cnt_i   = 0;
            start_i       = 1;
            wait_done;
        end
    endtask

    // RDSR1 - Read Status Register 1 (0x05), 1 byte read
    task op_rdsr1;
        output [7:0] status;
        reg [31:0] tmp;
        begin
            $display("[%0t] RDSR1", $time);
            instr_i       = 8'h05;
            has_address_i = 0;
            data_mode_i   = 2'b01;
            data_dir_i    = 0;
            data_cnt_i    = 8'd0; // 1 byte
            dummy_cnt_i   = 0;
            start_i       = 1;
            wait_done;
            pop_tx_fifo(tmp);
            status = tmp[7:0];
            $display("[%0t] RDSR1 = 0x%02x", $time, status);
        end
    endtask

    // Poll WIP bit until clear
    task wait_not_busy;
        reg [7:0] sr;
        begin
            sr = 8'h01;
            while (sr[0]) begin
                do_ticks(5);
                op_rdsr1(sr);
                $display("[%0t] WIP polling: SR1=0x%02x", $time, sr);
            end
            $display("[%0t] Flash ready", $time);
        end
    endtask

    // SE - Sector Erase (0x20 = 4KB), cmd + 3-byte addr
    task op_sector_erase;
        input [31:0] address;
        begin
            $display("[%0t] SE addr=0x%08x", $time, address);
            op_wren;
            instr_i       = 8'h20;
            has_address_i = 1;
            data_mode_i   = 2'b00;
            data_dir_i    = 0;
            dummy_cnt_i   = 0;
            addr_i        = address;
            start_i       = 1;
            wait_done;
            wait_not_busy;
        end
    endtask

    // PP - Page Program (0x02), cmd + addr + write data
    task op_page_program;
        input [31:0] address;
        input [7:0]  byte_cnt_minus1; // data_cnt_i convention
        begin
            $display("[%0t] PP addr=0x%08x cnt=%0d", $time, address, byte_cnt_minus1+1);
            op_wren;
            instr_i       = 8'h02;
            has_address_i = 1;
            data_mode_i   = 2'b01;
            data_dir_i    = 1;
            dummy_cnt_i   = 0;
            addr_i        = address;
            data_cnt_i    = byte_cnt_minus1;
            start_i       = 1;
            wait_done;
            wait_not_busy;
        end
    endtask

    // READ - Read Data (0x03), cmd + addr + read data
    task op_read;
        input  [31:0] address;
        input  [7:0]  byte_cnt_minus1;
        begin
            $display("[%0t] READ addr=0x%08x cnt=%0d", $time, address, byte_cnt_minus1+1);
            instr_i       = 8'h03;
            has_address_i = 1;
            data_mode_i   = 2'b01;
            data_dir_i    = 0;
            dummy_cnt_i   = 0;
            addr_i        = address;
            data_cnt_i    = byte_cnt_minus1;
            start_i       = 1;
            wait_done;
        end
    endtask
    
    // READ_ID - Read Manufacturer/Device ID (0x90), 3 dummy bytes then 2 read bytes
    task op_read_id;
        output [7:0] mfr;
        output [7:0] dev;
        reg [31:0] tmp;
        begin
            $display("[%0t] READ_ID", $time);
            instr_i       = 8'h90;
            has_address_i = 1;      // 3 address bytes (all 0x00)
            addr_i        = 32'h0;
            data_mode_i   = 2'b01;
            data_dir_i    = 0;
            dummy_cnt_i   = 0;
            data_cnt_i    = 8'd1;   // 2 bytes
            start_i       = 1;
            wait_done;
            pop_tx_fifo(tmp);
            mfr = tmp[7:0];
            dev = tmp[15:8];
            $display("[%0t] MFR=0x%02x DEV=0x%02x", $time, mfr, dev);
        end
    endtask

    // -------------------------------------------------------------------------
    // Test body
    // -------------------------------------------------------------------------
    reg [7:0]  sr1;
    reg [7:0]  mfr_id, dev_id;
    reg [31:0] rd_word;
    integer    i;
    reg [31:0] wr_word;
    reg [7:0] b0, b1, b2, b3;


    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_qspi_nor);

        defaults;
        rst_n = 0;
        do_ticks(5);
        rst_n = 1;
        do_ticks(10);

        // ------------------------------------------------------------------
        // Test 1: Read ID
        // ------------------------------------------------------------------
        $display("=== Test 1: READ_ID ===");
        op_read_id(mfr_id, dev_id);
        if (mfr_id !== 8'hEF)
            $display("FAIL: expected MFR=0xEF got 0x%02x", mfr_id);
        else
            $display("PASS: MFR ID correct");

        // ------------------------------------------------------------------
        // Test 2: RDSR1 - status should be 0x00 after reset (not busy)
        // ------------------------------------------------------------------
        $display("=== Test 2: RDSR1 ===");
        op_rdsr1(sr1);
        if (sr1[0] !== 1'b0)
            $display("FAIL: WIP should be clear, got SR1=0x%02x", sr1);
        else
            $display("PASS: WIP clear");

        // ------------------------------------------------------------------
        // Test 3: Sector Erase then verify reads 0xFF
        // ------------------------------------------------------------------
        $display("=== Test 3: Sector Erase ===");
        op_sector_erase(32'h000000);
        op_read(32'h000000, 8'd3); // read 4 bytes
        for (i = 0; i < 1; i = i + 1) begin
            pop_tx_fifo(rd_word);
            $display("  read back after erase: 0x%08x (expect 0xFFFFFFFF)", rd_word);
            if (rd_word !== 32'hFFFFFFFF)
                $display("FAIL: expected 0xFFFFFFFF");
            else
                $display("PASS");
        end

        // ------------------------------------------------------------------
        // Test 4: Page Program 4 bytes then read back
        // ------------------------------------------------------------------
        $display("=== Test 4: Page Program + Read ===");

        // push 1 word (4 bytes) into rx fifo
        push_rx_fifo(32'hDEADBEEF);

        op_page_program(32'h000000, 8'd3); // 4 bytes

        // read back
        op_read(32'h000000, 8'd3);
        pop_tx_fifo(rd_word);

        $display("  read back: 0x%08x (expect 0xDEADBEEF)", rd_word);
//        if (rd_word !== 32'hDEADBEEF)
//            $display("FAIL");
//        else
//            $display("PASS");

        // ------------------------------------------------------------------
        // Test 5: Page Program 16 bytes then read back
        // ------------------------------------------------------------------
        $display("=== Test 5: Page Program 16 bytes ===");
        op_sector_erase(32'h001000);

        push_rx_fifo(32'h04030201);
        push_rx_fifo(32'h08070605);
        push_rx_fifo(32'h0C0B0A09);
        push_rx_fifo(32'h100F0E0D);

        op_page_program(32'h001000, 8'd15); // 16 bytes

        op_read(32'h001000, 8'd15);
        for (i = 0; i < 4; i = i + 1) begin
            pop_tx_fifo(rd_word);
            $display("  word[%0d] = 0x%08x", i, rd_word);
        end
        
        $display("=== Test 5b: PP 16 bytes 0xAA55 pattern ===");
        op_sector_erase(32'h002000);
        
        for (i = 0; i < 50; i = i + 1) begin
            b0 = i*4 + 0;
            b1 = i*4 + 1;
            b2 = i*4 + 2;
            b3 = i*4 + 3;
            push_rx_fifo({b3, b2, b1, b0});
        end
        
        op_page_program(32'h003000, 8'd199);
      
        op_read(32'h003000, 8'd199);
        
        for (i = 0; i < 50; i = i + 1) begin
            b0 = i*4 + 0;
            b1 = i*4 + 1;
            b2 = i*4 + 2;
            b3 = i*4 + 3;
            wr_word = {b3, b2, b1, b0};
            pop_tx_fifo(rd_word);
            $display("  word[%0d] = 0x%08x (expected: 0x%08x)", i, rd_word, wr_word);
        end

        // ------------------------------------------------------------------
        // Test 6: WREN + WRDI - check WEL bit
        // ------------------------------------------------------------------
        $display("=== Test 6: WREN/WRDI ===");
        op_wren;
        op_rdsr1(sr1);
        if (sr1[1] !== 1'b1)
            $display("FAIL: WEL should be set after WREN, SR1=0x%02x", sr1);
        else
            $display("PASS: WEL set");

        // WRDI
        instr_i       = 8'h04;
        has_address_i = 0;
        data_mode_i   = 2'b00;
        start_i       = 1;
        wait_done;

        op_rdsr1(sr1);
        if (sr1[1] !== 1'b0)
            $display("FAIL: WEL should be clear after WRDI, SR1=0x%02x", sr1);
        else
            $display("PASS: WEL cleared");

        // ------------------------------------------------------------------
        $display("=== All tests done ===");
        do_ticks(50);
        $finish;
    end

endmodule