module picosoc (
    input wire clk_i,
    // input wire rst_n,

//    input  wire [15:0] gpio_in,
//    output wire [15:0] gpio_out,

    input  wire uart_rx_i,
    output wire uart_tx_o,

    output wire cs_n_o,
    output wire mosi_o,
    input wire miso_i,
    output wire spi_clk_o,
    
    output wire led,

    output wire mdc_o,
    inout  wire mdio
);
//     blink_led led_inst (
//         .clk(clk_i),
//         .led(led)
//     );
    // assign rst_n = 1'b1;
    reg rst_n;
    reg [6:0] reset_counter;

    initial begin
        reset_counter = 0;
        rst_n = 1'b0;
    end

    always @(posedge clk_i) begin
        if (reset_counter < 100) begin
            reset_counter <= reset_counter + 1'b1;
            rst_n <= 1'b0;
        end
        else begin
            rst_n <= 1'b1;
        end
    end
    
    wire [15:0] gpio_in;
    wire [15:0] gpio_out;
    assign gpio_in = gpio_out;
    wire        trap;

    // =========================================================
    // CPU <-> Interconnect (AXI4-Lite Master)
    // =========================================================
(* mark_debug = "true" *) wire        mem_axi_awvalid;
(* mark_debug = "true" *) wire        mem_axi_awready;
(* mark_debug = "true" *) wire [31:0] mem_axi_awaddr;
    wire [2:0]  mem_axi_awprot;

(* mark_debug = "true" *) wire        mem_axi_wvalid;
(* mark_debug = "true" *) wire        mem_axi_wready;
(* mark_debug = "true" *) wire [31:0] mem_axi_wdata;
(* mark_debug = "true" *) wire [3:0]  mem_axi_wstrb;

    wire [1:0]  mem_axi_bresp;
(* mark_debug = "true" *) wire        mem_axi_bvalid;
(* mark_debug = "true" *) wire        mem_axi_bready;

(* mark_debug = "true" *) wire        mem_axi_arvalid;
(* mark_debug = "true" *) wire        mem_axi_arready;
(* mark_debug = "true" *) wire [31:0] mem_axi_araddr;
    wire [2:0]  mem_axi_arprot;

(* mark_debug = "true" *) wire        mem_axi_rvalid;
(* mark_debug = "true" *) wire        mem_axi_rready;
(* mark_debug = "true" *) wire [31:0] mem_axi_rdata;
    wire [1:0]  mem_axi_rresp;
    
    // ila_0 u_ila (
    //     .clk    (clk_i),

    //     // AXI Write Address
    //     .probe0 ({
    //         mem_axi_awvalid,
    //         mem_axi_awready,
    //         mem_axi_awaddr
    //     }),

    //     // AXI Write Data
    //     .probe1 ({
    //         mem_axi_wvalid,
    //         mem_axi_wready,
    //         mem_axi_wdata,
    //         mem_axi_wstrb
    //     }),

    //     // AXI Write Response
    //     .probe2 ({
    //         mem_axi_bvalid,
    //         mem_axi_bready,
    //         mem_axi_bresp
    //     }),

    //     // AXI Read Address
    //     .probe3 ({
    //         mem_axi_arvalid,
    //         mem_axi_arready,
    //         mem_axi_araddr
    //     }),

    //     // AXI Read Data
    //     .probe4 ({
    //         mem_axi_rvalid,
    //         mem_axi_rready,
    //         mem_axi_rdata
    //     })
    // );

    // =========================================================
    // Interconnect -> Slave 0: INSTR_MEM (axil_rom)
    // =========================================================
    wire [31:0] s0_axi_awaddr;
    wire        s0_axi_awvalid;
    wire        s0_axi_awready;
    wire [31:0] s0_axi_wdata;
    wire [3:0]  s0_axi_wstrb;
    wire        s0_axi_wvalid;
    wire        s0_axi_wready;
    wire [1:0]  s0_axi_bresp;
    wire        s0_axi_bvalid;
    wire        s0_axi_bready;
    wire [31:0] s0_axi_araddr;
    wire        s0_axi_arvalid;
    wire        s0_axi_arready;
    wire [31:0] s0_axi_rdata;
    wire [1:0]  s0_axi_rresp;
    wire        s0_axi_rvalid;
    wire        s0_axi_rready;

    // =========================================================
    // Interconnect -> Slave 1: DATA_MEM (axil_ram)
    // =========================================================
    wire [31:0] s1_axi_awaddr;
    wire        s1_axi_awvalid;
    wire        s1_axi_awready;
    wire [31:0] s1_axi_wdata;
    wire [3:0]  s1_axi_wstrb;
    wire        s1_axi_wvalid;
    wire        s1_axi_wready;
    wire [1:0]  s1_axi_bresp;
    wire        s1_axi_bvalid;
    wire        s1_axi_bready;
    wire [31:0] s1_axi_araddr;
    wire        s1_axi_arvalid;
    wire        s1_axi_arready;
    wire [31:0] s1_axi_rdata;
    wire [1:0]  s1_axi_rresp;
    wire        s1_axi_rvalid;
    wire        s1_axi_rready;

    // =========================================================
    // Interconnect -> Slave 2: GPIO (axi_gpio)
    // =========================================================
    wire [31:0] s2_axi_awaddr;
    wire        s2_axi_awvalid;
    wire        s2_axi_awready;
    wire [31:0] s2_axi_wdata;
    wire [3:0]  s2_axi_wstrb;
    wire        s2_axi_wvalid;
    wire        s2_axi_wready;
    wire [1:0]  s2_axi_bresp;
    wire        s2_axi_bvalid;
    wire        s2_axi_bready;
    wire [31:0] s2_axi_araddr;
    wire        s2_axi_arvalid;
    wire        s2_axi_arready;
    wire [31:0] s2_axi_rdata;
    wire [1:0]  s2_axi_rresp;
    wire        s2_axi_rvalid;
    wire        s2_axi_rready;

    // =====================================================
    // Slave 3: UART
    // =====================================================
    wire [31:0] s3_axi_awaddr;
    wire        s3_axi_awvalid;
    wire        s3_axi_awready;
    wire [31:0] s3_axi_wdata;
    wire [3:0]  s3_axi_wstrb;
    wire        s3_axi_wvalid;
    wire        s3_axi_wready;
    wire [1:0]  s3_axi_bresp;
    wire        s3_axi_bvalid;
    wire        s3_axi_bready;
    wire [31:0] s3_axi_araddr;
    wire        s3_axi_arvalid;
    wire        s3_axi_arready;
    wire [31:0] s3_axi_rdata;
    wire [1:0]  s3_axi_rresp;
    wire        s3_axi_rvalid;
    wire        s3_axi_rready;

    // =====================================================
    // Slave 4: fifo loopback
    // =====================================================
    wire [31:0] s4_axi_awaddr;
    wire        s4_axi_awvalid;
    wire        s4_axi_awready;
    wire [31:0] s4_axi_wdata;
    wire [3:0]  s4_axi_wstrb;
    wire        s4_axi_wvalid;
    wire        s4_axi_wready;
    wire [1:0]  s4_axi_bresp;
    wire        s4_axi_bvalid;
    wire        s4_axi_bready;
    wire [31:0] s4_axi_araddr;
    wire        s4_axi_arvalid;
    wire        s4_axi_arready;
    wire [31:0] s4_axi_rdata;
    wire [1:0]  s4_axi_rresp;
    wire        s4_axi_rvalid;
    wire        s4_axi_rready;    

    // =====================================================
    // Slave 5: qspi
    // =====================================================
    wire [31:0] s5_axi_awaddr;
    wire        s5_axi_awvalid;
    wire        s5_axi_awready;
    wire [31:0] s5_axi_wdata;
    wire [3:0]  s5_axi_wstrb;
    wire        s5_axi_wvalid;
    wire        s5_axi_wready;
    wire [1:0]  s5_axi_bresp;
    wire        s5_axi_bvalid;
    wire        s5_axi_bready;
    wire [31:0] s5_axi_araddr;
    wire        s5_axi_arvalid;
    wire        s5_axi_arready;
    wire [31:0] s5_axi_rdata;
    wire [1:0]  s5_axi_rresp;
    wire        s5_axi_rvalid;
    wire        s5_axi_rready;      

    // =====================================================
    // Slave 5: qspi
    // =====================================================
    wire [31:0] s6_axi_awaddr;
    wire        s6_axi_awvalid;
    wire        s6_axi_awready;
    wire [31:0] s6_axi_wdata;
    wire [3:0]  s6_axi_wstrb;
    wire        s6_axi_wvalid;
    wire        s6_axi_wready;
    wire [1:0]  s6_axi_bresp;
    wire        s6_axi_bvalid;
    wire        s6_axi_bready;
    wire [31:0] s6_axi_araddr;
    wire        s6_axi_arvalid;
    wire        s6_axi_arready;
    wire [31:0] s6_axi_rdata;
    wire [1:0]  s6_axi_rresp;
    wire        s6_axi_rvalid;
    wire        s6_axi_rready;  

    // PCPI (tied off — no co-processor)
    wire        pcpi_valid;
    wire [31:0] pcpi_insn;
    wire [31:0] pcpi_rs1;
    wire [31:0] pcpi_rs2;
    wire        pcpi_wr   = 1'b0;
    wire [31:0] pcpi_rd   = 32'h0;
    wire        pcpi_wait = 1'b0;
    wire        pcpi_ready= 1'b0;

    // IRQ (tied off)
    wire [31:0] irq = 32'h0;
    wire [31:0] eoi;

    // Trace (unused)
    wire        trace_valid;
    wire [35:0] trace_data;

    // =========================================================
    // PicoRV32 CPU
    // =========================================================
    picorv32_axi #(
        .ENABLE_COUNTERS     (1),
        .ENABLE_COUNTERS64   (1),
        .ENABLE_REGS_16_31   (1),
        .ENABLE_REGS_DUALPORT(1),
        .TWO_STAGE_SHIFT     (1),
        .BARREL_SHIFTER      (0),
        .TWO_CYCLE_COMPARE   (0),
        .TWO_CYCLE_ALU       (0),
        .COMPRESSED_ISA      (0),
        .CATCH_MISALIGN      (1),
        .CATCH_ILLINSN       (1),
        .ENABLE_PCPI         (0),
        .ENABLE_MUL          (0),
        .ENABLE_FAST_MUL     (0),
        .ENABLE_DIV          (0),
        .ENABLE_IRQ          (0),
        .ENABLE_IRQ_QREGS    (1),
        .ENABLE_IRQ_TIMER    (1),
        .ENABLE_TRACE        (0),
        .REGS_INIT_ZERO      (0),
        .MASKED_IRQ          (32'h0000_0000),
        .LATCHED_IRQ         (32'hffff_ffff),
        .PROGADDR_RESET      (32'h1000_0000),  // boot from INSTR_MEM
        .PROGADDR_IRQ        (32'h1000_0010),
        .STACKADDR           (32'h2000_8000)   // top of DATA_MEM
    ) picorv32_core (
        .clk    (clk_i),
        .resetn (rst_n),
        .trap   (trap),

        .mem_axi_awvalid(mem_axi_awvalid),
        .mem_axi_awready(mem_axi_awready),
        .mem_axi_awaddr (mem_axi_awaddr),
        .mem_axi_awprot (mem_axi_awprot),

        .mem_axi_wvalid (mem_axi_wvalid),
        .mem_axi_wready (mem_axi_wready),
        .mem_axi_wdata  (mem_axi_wdata),
        .mem_axi_wstrb  (mem_axi_wstrb),

        .mem_axi_bvalid (mem_axi_bvalid),
        .mem_axi_bready (mem_axi_bready),

        .mem_axi_arvalid(mem_axi_arvalid),
        .mem_axi_arready(mem_axi_arready),
        .mem_axi_araddr (mem_axi_araddr),
        .mem_axi_arprot (mem_axi_arprot),

        .mem_axi_rvalid (mem_axi_rvalid),
        .mem_axi_rready (mem_axi_rready),
        .mem_axi_rdata  (mem_axi_rdata),

        .pcpi_valid(pcpi_valid),
        .pcpi_insn (pcpi_insn),
        .pcpi_rs1  (pcpi_rs1),
        .pcpi_rs2  (pcpi_rs2),
        .pcpi_wr   (pcpi_wr),
        .pcpi_rd   (pcpi_rd),
        .pcpi_wait (pcpi_wait),
        .pcpi_ready(pcpi_ready),

        .irq        (irq),
        .eoi        (eoi),
        .trace_valid(trace_valid),
        .trace_data (trace_data)
    );

    axi_interconnect axi_inst (
        .clk_i  (clk_i),
        .rst_ni (rst_n),

        // Master port (from CPU)
        .m_axi_awaddr  (mem_axi_awaddr),
        .m_axi_awvalid (mem_axi_awvalid),
        .m_axi_awready (mem_axi_awready),
        .m_axi_wdata   (mem_axi_wdata),
        .m_axi_wstrb   (mem_axi_wstrb),
        .m_axi_wvalid  (mem_axi_wvalid),
        .m_axi_wready  (mem_axi_wready),
        .m_axi_bresp   (mem_axi_bresp),
        .m_axi_bvalid  (mem_axi_bvalid),
        .m_axi_bready  (mem_axi_bready),
        .m_axi_araddr  (mem_axi_araddr),
        .m_axi_arvalid (mem_axi_arvalid),
        .m_axi_arready (mem_axi_arready),
        .m_axi_rdata   (mem_axi_rdata),
        .m_axi_rresp   (mem_axi_rresp),
        .m_axi_rvalid  (mem_axi_rvalid),
        .m_axi_rready  (mem_axi_rready),

        // Slave 0: INSTR_MEM
        .s0_axi_awaddr  (s0_axi_awaddr),
        .s0_axi_awvalid (s0_axi_awvalid),
        .s0_axi_awready (s0_axi_awready),
        .s0_axi_wdata   (s0_axi_wdata),
        .s0_axi_wstrb   (s0_axi_wstrb),
        .s0_axi_wvalid  (s0_axi_wvalid),
        .s0_axi_wready  (s0_axi_wready),
        .s0_axi_bresp   (s0_axi_bresp),
        .s0_axi_bvalid  (s0_axi_bvalid),
        .s0_axi_bready  (s0_axi_bready),
        .s0_axi_araddr  (s0_axi_araddr),
        .s0_axi_arvalid (s0_axi_arvalid),
        .s0_axi_arready (s0_axi_arready),
        .s0_axi_rdata   (s0_axi_rdata),
        .s0_axi_rresp   (s0_axi_rresp),
        .s0_axi_rvalid  (s0_axi_rvalid),
        .s0_axi_rready  (s0_axi_rready),

        // Slave 1: DATA_MEM
        .s1_axi_awaddr  (s1_axi_awaddr),
        .s1_axi_awvalid (s1_axi_awvalid),
        .s1_axi_awready (s1_axi_awready),
        .s1_axi_wdata   (s1_axi_wdata),
        .s1_axi_wstrb   (s1_axi_wstrb),
        .s1_axi_wvalid  (s1_axi_wvalid),
        .s1_axi_wready  (s1_axi_wready),
        .s1_axi_bresp   (s1_axi_bresp),
        .s1_axi_bvalid  (s1_axi_bvalid),
        .s1_axi_bready  (s1_axi_bready),
        .s1_axi_araddr  (s1_axi_araddr),
        .s1_axi_arvalid (s1_axi_arvalid),
        .s1_axi_arready (s1_axi_arready),
        .s1_axi_rdata   (s1_axi_rdata),
        .s1_axi_rresp   (s1_axi_rresp),
        .s1_axi_rvalid  (s1_axi_rvalid),
        .s1_axi_rready  (s1_axi_rready),

        // Slave 2: GPIO
        .s2_axi_awaddr  (s2_axi_awaddr),
        .s2_axi_awvalid (s2_axi_awvalid),
        .s2_axi_awready (s2_axi_awready),
        .s2_axi_wdata   (s2_axi_wdata),
        .s2_axi_wstrb   (s2_axi_wstrb),
        .s2_axi_wvalid  (s2_axi_wvalid),
        .s2_axi_wready  (s2_axi_wready),
        .s2_axi_bresp   (s2_axi_bresp),
        .s2_axi_bvalid  (s2_axi_bvalid),
        .s2_axi_bready  (s2_axi_bready),
        .s2_axi_araddr  (s2_axi_araddr),
        .s2_axi_arvalid (s2_axi_arvalid),
        .s2_axi_arready (s2_axi_arready),
        .s2_axi_rdata   (s2_axi_rdata),
        .s2_axi_rresp   (s2_axi_rresp),
        .s2_axi_rvalid  (s2_axi_rvalid),
        .s2_axi_rready  (s2_axi_rready),

        .s3_axi_awaddr  (s3_axi_awaddr),
        .s3_axi_awvalid (s3_axi_awvalid),
        .s3_axi_awready (s3_axi_awready),
        .s3_axi_wdata   (s3_axi_wdata),
        .s3_axi_wstrb   (s3_axi_wstrb),
        .s3_axi_wvalid  (s3_axi_wvalid),
        .s3_axi_wready  (s3_axi_wready),
        .s3_axi_bresp   (s3_axi_bresp),
        .s3_axi_bvalid  (s3_axi_bvalid),
        .s3_axi_bready  (s3_axi_bready),
        .s3_axi_araddr  (s3_axi_araddr),
        .s3_axi_arvalid (s3_axi_arvalid),
        .s3_axi_arready (s3_axi_arready),
        .s3_axi_rdata   (s3_axi_rdata),
        .s3_axi_rresp   (s3_axi_rresp),
        .s3_axi_rvalid  (s3_axi_rvalid),
        .s3_axi_rready  (s3_axi_rready),

        .s4_axi_awaddr  (s4_axi_awaddr),
        .s4_axi_awvalid (s4_axi_awvalid),
        .s4_axi_awready (s4_axi_awready),
        .s4_axi_wdata   (s4_axi_wdata),
        .s4_axi_wstrb   (s4_axi_wstrb),
        .s4_axi_wvalid  (s4_axi_wvalid),
        .s4_axi_wready  (s4_axi_wready),
        .s4_axi_bresp   (s4_axi_bresp),
        .s4_axi_bvalid  (s4_axi_bvalid),
        .s4_axi_bready  (s4_axi_bready),
        .s4_axi_araddr  (s4_axi_araddr),
        .s4_axi_arvalid (s4_axi_arvalid),
        .s4_axi_arready (s4_axi_arready),
        .s4_axi_rdata   (s4_axi_rdata),
        .s4_axi_rresp   (s4_axi_rresp),
        .s4_axi_rvalid  (s4_axi_rvalid),
        .s4_axi_rready  (s4_axi_rready),
        
        .s5_axi_awaddr  (s5_axi_awaddr),
        .s5_axi_awvalid (s5_axi_awvalid),
        .s5_axi_awready (s5_axi_awready),
        .s5_axi_wdata   (s5_axi_wdata),
        .s5_axi_wstrb   (s5_axi_wstrb),
        .s5_axi_wvalid  (s5_axi_wvalid),
        .s5_axi_wready  (s5_axi_wready),
        .s5_axi_bresp   (s5_axi_bresp),
        .s5_axi_bvalid  (s5_axi_bvalid),
        .s5_axi_bready  (s5_axi_bready),
        .s5_axi_araddr  (s5_axi_araddr),
        .s5_axi_arvalid (s5_axi_arvalid),
        .s5_axi_arready (s5_axi_arready),
        .s5_axi_rdata   (s5_axi_rdata),
        .s5_axi_rresp   (s5_axi_rresp),
        .s5_axi_rvalid  (s5_axi_rvalid),
        .s5_axi_rready  (s5_axi_rready),
        
        .s6_axi_awaddr  (s6_axi_awaddr),
        .s6_axi_awvalid (s6_axi_awvalid),
        .s6_axi_awready (s6_axi_awready),
        .s6_axi_wdata   (s6_axi_wdata),
        .s6_axi_wstrb   (s6_axi_wstrb),
        .s6_axi_wvalid  (s6_axi_wvalid),
        .s6_axi_wready  (s6_axi_wready),
        .s6_axi_bresp   (s6_axi_bresp),
        .s6_axi_bvalid  (s6_axi_bvalid),
        .s6_axi_bready  (s6_axi_bready),
        .s6_axi_araddr  (s6_axi_araddr),
        .s6_axi_arvalid (s6_axi_arvalid),
        .s6_axi_arready (s6_axi_arready),
        .s6_axi_rdata   (s6_axi_rdata),
        .s6_axi_rresp   (s6_axi_rresp),
        .s6_axi_rvalid  (s6_axi_rvalid),
        .s6_axi_rready  (s6_axi_rready)  
    );

    // =========================================================
    // Slave 0: Instruction ROM (axil_rom @ 0x10000000)
    // =========================================================
    axil_rom #(
        .C_AXI_ADDR_WIDTH(15)
    ) instr_mem (
        .S_AXI_ACLK    (clk_i),
        .S_AXI_ARESETN (rst_n),

        .S_AXI_AWVALID (s0_axi_awvalid),
        .S_AXI_AWREADY (s0_axi_awready),
        .S_AXI_AWADDR  (s0_axi_awaddr[14:0]),
        .S_AXI_AWPROT  (3'b0),

        .S_AXI_WVALID  (s0_axi_wvalid),
        .S_AXI_WREADY  (s0_axi_wready),
        .S_AXI_WDATA   (s0_axi_wdata),
        .S_AXI_WSTRB   (s0_axi_wstrb),

        .S_AXI_BVALID  (s0_axi_bvalid),
        .S_AXI_BREADY  (s0_axi_bready),
        .S_AXI_BRESP   (s0_axi_bresp),

        .S_AXI_ARVALID (s0_axi_arvalid),
        .S_AXI_ARREADY (s0_axi_arready),
        .S_AXI_ARADDR  (s0_axi_araddr[14:0]),
        .S_AXI_ARPROT  (3'b0),

        .S_AXI_RVALID  (s0_axi_rvalid),
        .S_AXI_RREADY  (s0_axi_rready),
        .S_AXI_RDATA   (s0_axi_rdata),
        .S_AXI_RRESP   (s0_axi_rresp)
    );

    // =========================================================
    // Slave 1: Data RAM (axil_ram @ 0x20000000)
    // =========================================================
    axil_ram #(
        .C_AXI_ADDR_WIDTH(15)
    ) data_mem (
        .S_AXI_ACLK    (clk_i),
        .S_AXI_ARESETN (rst_n),

        .S_AXI_AWVALID (s1_axi_awvalid),
        .S_AXI_AWREADY (s1_axi_awready),
        .S_AXI_AWADDR  (s1_axi_awaddr[14:0]),
        .S_AXI_AWPROT  (3'b0),

        .S_AXI_WVALID  (s1_axi_wvalid),
        .S_AXI_WREADY  (s1_axi_wready),
        .S_AXI_WDATA   (s1_axi_wdata),
        .S_AXI_WSTRB   (s1_axi_wstrb),

        .S_AXI_BVALID  (s1_axi_bvalid),
        .S_AXI_BREADY  (s1_axi_bready),
        .S_AXI_BRESP   (s1_axi_bresp),

        .S_AXI_ARVALID (s1_axi_arvalid),
        .S_AXI_ARREADY (s1_axi_arready),
        .S_AXI_ARADDR  (s1_axi_araddr[14:0]),
        .S_AXI_ARPROT  (3'b0),

        .S_AXI_RVALID  (s1_axi_rvalid),
        .S_AXI_RREADY  (s1_axi_rready),
        .S_AXI_RDATA   (s1_axi_rdata),
        .S_AXI_RRESP   (s1_axi_rresp)
    );

    // =========================================================
    // Slave 2: GPIO (axi_gpio @ 0x80000000)
    // =========================================================
    axi_gpio #(
        .C_AXI_ADDR_WIDTH(4)
    ) gpio (
        .S_AXI_ACLK    (clk_i),
        .S_AXI_ARESETN (rst_n),

        .S_AXI_AWVALID (s2_axi_awvalid),
        .S_AXI_AWREADY (s2_axi_awready),
        .S_AXI_AWADDR  (s2_axi_awaddr[3:0]),
        .S_AXI_AWPROT  (3'b0),

        .S_AXI_WVALID  (s2_axi_wvalid),
        .S_AXI_WREADY  (s2_axi_wready),
        .S_AXI_WDATA   (s2_axi_wdata),
        .S_AXI_WSTRB   (s2_axi_wstrb),

        .S_AXI_BVALID  (s2_axi_bvalid),
        .S_AXI_BREADY  (s2_axi_bready),
        .S_AXI_BRESP   (s2_axi_bresp),

        .S_AXI_ARVALID (s2_axi_arvalid),
        .S_AXI_ARREADY (s2_axi_arready),
        .S_AXI_ARADDR  (s2_axi_araddr[3:0]),
        .S_AXI_ARPROT  (3'b0),

        .S_AXI_RVALID  (s2_axi_rvalid),
        .S_AXI_RREADY  (s2_axi_rready),
        .S_AXI_RDATA   (s2_axi_rdata),
        .S_AXI_RRESP   (s2_axi_rresp),

        .gpio_in  (gpio_in),
        .gpio_out (gpio_out)
    );

    axi_uart #(
        .C_AXI_ADDR_WIDTH(5)
    ) uart (
        .S_AXI_ACLK    (clk_i),
        .S_AXI_ARESETN (rst_n),

        .S_AXI_AWVALID (s3_axi_awvalid),
        .S_AXI_AWREADY (s3_axi_awready),
        .S_AXI_AWADDR  (s3_axi_awaddr[4:0]),
        .S_AXI_AWPROT  (3'b0),

        .S_AXI_WVALID  (s3_axi_wvalid),
        .S_AXI_WREADY  (s3_axi_wready),
        .S_AXI_WDATA   (s3_axi_wdata),
        .S_AXI_WSTRB   (s3_axi_wstrb),

        .S_AXI_BVALID  (s3_axi_bvalid),
        .S_AXI_BREADY  (s3_axi_bready),
        .S_AXI_BRESP   (s3_axi_bresp),

        .S_AXI_ARVALID (s3_axi_arvalid),
        .S_AXI_ARREADY (s3_axi_arready),
        .S_AXI_ARADDR  (s3_axi_araddr[4:0]),
        .S_AXI_ARPROT  (3'b0),

        .S_AXI_RVALID  (s3_axi_rvalid),
        .S_AXI_RREADY  (s3_axi_rready),
        .S_AXI_RDATA   (s3_axi_rdata),
        .S_AXI_RRESP   (s3_axi_rresp),

        .uart_rx_i (uart_rx_i),
        .uart_tx_o (uart_tx_o)
    );

    axi_fifo #(
        .C_AXI_ADDR_WIDTH(4)
    ) fifo (
        .S_AXI_ACLK    (clk_i),
        .S_AXI_ARESETN (rst_n),

        .S_AXI_AWVALID (s4_axi_awvalid),
        .S_AXI_AWREADY (s4_axi_awready),
        .S_AXI_AWADDR  (s4_axi_awaddr[3:0]),
        .S_AXI_AWPROT  (3'b0),

        .S_AXI_WVALID  (s4_axi_wvalid),
        .S_AXI_WREADY  (s4_axi_wready),
        .S_AXI_WDATA   (s4_axi_wdata),
        .S_AXI_WSTRB   (s4_axi_wstrb),

        .S_AXI_BVALID  (s4_axi_bvalid),
        .S_AXI_BREADY  (s4_axi_bready),
        .S_AXI_BRESP   (s4_axi_bresp),

        .S_AXI_ARVALID (s4_axi_arvalid),
        .S_AXI_ARREADY (s4_axi_arready),
        .S_AXI_ARADDR  (s4_axi_araddr[3:0]),
        .S_AXI_ARPROT  (3'b0),

        .S_AXI_RVALID  (s4_axi_rvalid),
        .S_AXI_RREADY  (s4_axi_rready),
        .S_AXI_RDATA   (s4_axi_rdata),
        .S_AXI_RRESP   (s4_axi_rresp)
    );

    axi_qspi_nor_xilinx #(
        .C_AXI_ADDR_WIDTH(6)
    ) u_qspi_nor (
        .S_AXI_ACLK    (clk_i),
        .S_AXI_ARESETN (rst_n),

        .S_AXI_AWVALID (s5_axi_awvalid),
        .S_AXI_AWREADY (s5_axi_awready),
        .S_AXI_AWADDR  (s5_axi_awaddr[5:0]),
        .S_AXI_AWPROT  (3'b0),

        .S_AXI_WVALID  (s5_axi_wvalid),
        .S_AXI_WREADY  (s5_axi_wready),
        .S_AXI_WDATA   (s5_axi_wdata),
        .S_AXI_WSTRB   (s5_axi_wstrb),

        .S_AXI_BVALID  (s5_axi_bvalid),
        .S_AXI_BREADY  (s5_axi_bready),
        .S_AXI_BRESP   (s5_axi_bresp),

        .S_AXI_ARVALID (s5_axi_arvalid),
        .S_AXI_ARREADY (s5_axi_arready),
        .S_AXI_ARADDR  (s5_axi_araddr[5:0]),
        .S_AXI_ARPROT  (3'b0),

        .S_AXI_RVALID  (s5_axi_rvalid),
        .S_AXI_RREADY  (s5_axi_rready),
        .S_AXI_RDATA   (s5_axi_rdata),
        .S_AXI_RRESP   (s5_axi_rresp),

        // QSPI physical pins — connect to top-level ports or IOBUF
        .cs_n_o   (cs_n_o),
        .miso_i   (miso_i),
        .mosi_o   (mosi_o),
        .spi_clk_o(spi_clk_o)
    );

    axi_mdio_vivado #(
        .C_AXI_ADDR_WIDTH(4)
    ) u_mdio (
        .S_AXI_ACLK    (clk_i),
        .S_AXI_ARESETN (rst_n),

        .S_AXI_AWVALID (s6_axi_awvalid),
        .S_AXI_AWREADY (s6_axi_awready),
        .S_AXI_AWADDR  (s6_axi_awaddr[3:0]),

        .S_AXI_WVALID  (s6_axi_wvalid),
        .S_AXI_WREADY  (s6_axi_wready),
        .S_AXI_WDATA   (s6_axi_wdata),
        .S_AXI_WSTRB   (s6_axi_wstrb),

        .S_AXI_BVALID  (s6_axi_bvalid),
        .S_AXI_BREADY  (s6_axi_bready),
        .S_AXI_BRESP   (s6_axi_bresp),

        .S_AXI_ARVALID (s6_axi_arvalid),
        .S_AXI_ARREADY (s6_axi_arready),
        .S_AXI_ARADDR  (s6_axi_araddr[3:0]),

        .S_AXI_RVALID  (s6_axi_rvalid),
        .S_AXI_RREADY  (s6_axi_rready),
        .S_AXI_RDATA   (s6_axi_rdata),
        .S_AXI_RRESP   (s6_axi_rresp),

        .mdc_o (mdc_o),
        .mdio  (mdio)
    );

endmodule