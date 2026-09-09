module axi_mdio_vivado #(
    parameter C_AXI_ADDR_WIDTH = 4,
    localparam C_AXI_DATA_WIDTH = 32,
    parameter [0:0] OPT_LOWPOWER = 0
)(
    // keep your existing AXI ports here
    // directly connect them to axi_mmio

    input  wire S_AXI_ACLK,
    input  wire S_AXI_ARESETN,

    input  wire S_AXI_AWVALID,
    output wire S_AXI_AWREADY,
    input  wire [C_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,

    input  wire S_AXI_WVALID,
    output wire S_AXI_WREADY,
    input  wire [C_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input  wire [C_AXI_DATA_WIDTH/8-1:0] S_AXI_WSTRB,

    output wire S_AXI_BVALID,
    input  wire S_AXI_BREADY,
    output wire [1:0] S_AXI_BRESP,

    input  wire S_AXI_ARVALID,
    output wire S_AXI_ARREADY,
    input  wire [C_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,

    output wire S_AXI_RVALID,
    input  wire S_AXI_RREADY,
    output wire [C_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output wire [1:0] S_AXI_RRESP,


    // physical pins
    output wire mdc_o,
    inout  wire mdio
);

wire mdio_o;
wire mdio_i;
wire mdio_oe;

/*
 * Existing AXI MMIO block
 */
axi_mdio axi_mdio_inst (

    .S_AXI_ACLK      (S_AXI_ACLK),
    .S_AXI_ARESETN   (S_AXI_ARESETN),

    .S_AXI_AWVALID   (S_AXI_AWVALID),
    .S_AXI_AWREADY   (S_AXI_AWREADY),
    .S_AXI_AWADDR    (S_AXI_AWADDR),

    .S_AXI_WVALID    (S_AXI_WVALID),
    .S_AXI_WREADY    (S_AXI_WREADY),
    .S_AXI_WDATA     (S_AXI_WDATA),
    .S_AXI_WSTRB     (S_AXI_WSTRB),

    .S_AXI_BVALID    (S_AXI_BVALID),
    .S_AXI_BREADY    (S_AXI_BREADY),
    .S_AXI_BRESP     (S_AXI_BRESP),

    .S_AXI_ARVALID   (S_AXI_ARVALID),
    .S_AXI_ARREADY   (S_AXI_ARREADY),
    .S_AXI_ARADDR    (S_AXI_ARADDR),

    .S_AXI_RVALID    (S_AXI_RVALID),
    .S_AXI_RREADY    (S_AXI_RREADY),
    .S_AXI_RDATA     (S_AXI_RDATA),
    .S_AXI_RRESP     (S_AXI_RRESP),


    .mdc_o           (mdc_o),
    .mdio_o          (mdio_o),
    .mdio_i          (mdio_i),
    .mdio_oe_o       (mdio_oe)
);

/*
 * Xilinx bidirectional IO
 *
 * mdio_oe = 1 : FPGA drives
 * mdio_oe = 0 : high impedance
 */
IOBUF mdio_buf (
    .I  (mdio_o),
    .O  (mdio_i),
    .T  (~mdio_oe),
    .IO (mdio)
);

endmodule