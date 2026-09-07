module axi_qspi_nor_xilinx #(
    parameter C_AXI_ADDR_WIDTH = 6,
    localparam C_AXI_DATA_WIDTH = 32,
    parameter [0:0] OPT_LOWPOWER = 0
) (
    input  wire                           S_AXI_ACLK,
    input  wire                           S_AXI_ARESETN,

    input  wire                           S_AXI_AWVALID,
    output wire                           S_AXI_AWREADY,
    input  wire [C_AXI_ADDR_WIDTH-1:0]   S_AXI_AWADDR,
    input  wire [2:0]                     S_AXI_AWPROT,

    input  wire                           S_AXI_WVALID,
    output wire                           S_AXI_WREADY,
    input  wire [C_AXI_DATA_WIDTH-1:0]   S_AXI_WDATA,
    input  wire [C_AXI_DATA_WIDTH/8-1:0] S_AXI_WSTRB,

    output wire                           S_AXI_BVALID,
    input  wire                           S_AXI_BREADY,
    output wire [1:0]                     S_AXI_BRESP,

    input  wire                           S_AXI_ARVALID,
    output wire                           S_AXI_ARREADY,
    input  wire [C_AXI_ADDR_WIDTH-1:0]   S_AXI_ARADDR,
    input  wire [2:0]                     S_AXI_ARPROT,

    output wire                           S_AXI_RVALID,
    input  wire                           S_AXI_RREADY,
    output wire [C_AXI_DATA_WIDTH-1:0]   S_AXI_RDATA,
    output wire [1:0]                     S_AXI_RRESP,

    // QSPI NOR physical pins
    output wire  cs_n_o,
    input  wire  miso_i,
    output wire  mosi_o,
    output wire  spi_clk_o      // driven by ODDR, not raw fabric
);

    // Internal SPI clock and enable from axi_qspi_nor
    wire spi_clk_fabric;
    wire spi_clk_en;

    // -------------------------------------------------------------------------
    // axi_qspi_nor instance — pass all AXI wires straight through
    // -------------------------------------------------------------------------
    axi_qspi_nor #(
        .C_AXI_ADDR_WIDTH (C_AXI_ADDR_WIDTH),
        .OPT_LOWPOWER     (OPT_LOWPOWER)
    ) u_axi_qspi_nor (
        .S_AXI_ACLK     (S_AXI_ACLK),
        .S_AXI_ARESETN  (S_AXI_ARESETN),

        .S_AXI_AWVALID  (S_AXI_AWVALID),
        .S_AXI_AWREADY  (S_AXI_AWREADY),
        .S_AXI_AWADDR   (S_AXI_AWADDR),
        .S_AXI_AWPROT   (S_AXI_AWPROT),

        .S_AXI_WVALID   (S_AXI_WVALID),
        .S_AXI_WREADY   (S_AXI_WREADY),
        .S_AXI_WDATA    (S_AXI_WDATA),
        .S_AXI_WSTRB    (S_AXI_WSTRB),

        .S_AXI_BVALID   (S_AXI_BVALID),
        .S_AXI_BREADY   (S_AXI_BREADY),
        .S_AXI_BRESP    (S_AXI_BRESP),

        .S_AXI_ARVALID  (S_AXI_ARVALID),
        .S_AXI_ARREADY  (S_AXI_ARREADY),
        .S_AXI_ARADDR   (S_AXI_ARADDR),
        .S_AXI_ARPROT   (S_AXI_ARPROT),

        .S_AXI_RVALID   (S_AXI_RVALID),
        .S_AXI_RREADY   (S_AXI_RREADY),
        .S_AXI_RDATA    (S_AXI_RDATA),
        .S_AXI_RRESP    (S_AXI_RRESP),

        .cs_n_o         (cs_n_o),
        .miso_i         (miso_i),
        .mosi_o         (mosi_o),

        // Intercept these two — don't connect to top-level port
        .spi_clk_o      (spi_clk_fabric),
        .spi_clk_en     (spi_clk_en),
        .spi_clk_divided(spi_clk_divided)
    );

    // -------------------------------------------------------------------------
    // ODDR: forward spi_clk cleanly to the IOB
    //   D1=1, D2=0  →  output tracks clk_i (50 % duty cycle)
    //   CE=spi_clk_en  →  clock gated cleanly in the IOB, no glitch
    // -------------------------------------------------------------------------
    ODDR #(
        .DDR_CLK_EDGE ("SAME_EDGE"),
        .INIT         (1'b0),
        .SRTYPE       ("SYNC")
    ) u_spi_clk_oddr (
        .Q  (spi_clk_o),    // → IOB pin
        .C  (spi_clk_divided),  // spi divided clock
        .CE (spi_clk_en),   // gate: low holds output cleanly without glitching
        .D1 (1'b1),         // drive high on rising edge
        .D2 (1'b0),         // drive low  on falling edge
        .R  (1'b0),
        .S  (1'b0)
    );

    // spi_clk_fabric is unused here (ODDR replaces it); tie off for linting
    wire unused;
    assign unused = spi_clk_fabric;

endmodule