module axi_uart #(
    parameter  C_AXI_ADDR_WIDTH = 5,
    localparam C_AXI_DATA_WIDTH = 32,
    parameter [0:0] OPT_LOWPOWER = 0
) (
    input  wire                          S_AXI_ACLK,
    input  wire                          S_AXI_ARESETN,
    input  wire                          S_AXI_AWVALID,
    output wire                          S_AXI_AWREADY,
    input  wire [C_AXI_ADDR_WIDTH-1:0]  S_AXI_AWADDR,
    input  wire [2:0]                    S_AXI_AWPROT,
    input  wire                          S_AXI_WVALID,
    output wire                          S_AXI_WREADY,
    input  wire [C_AXI_DATA_WIDTH-1:0]  S_AXI_WDATA,
    input  wire [C_AXI_DATA_WIDTH/8-1:0] S_AXI_WSTRB,
    output wire                          S_AXI_BVALID,
    input  wire                          S_AXI_BREADY,
    output wire [1:0]                    S_AXI_BRESP,
    input  wire                          S_AXI_ARVALID,
    output wire                          S_AXI_ARREADY,
    input  wire [C_AXI_ADDR_WIDTH-1:0]  S_AXI_ARADDR,
    input  wire [2:0]                    S_AXI_ARPROT,
    output wire                          S_AXI_RVALID,
    input  wire                          S_AXI_RREADY,
    output wire [C_AXI_DATA_WIDTH-1:0]  S_AXI_RDATA,
    output wire [1:0]                    S_AXI_RRESP,
    input  wire                          uart_rx_i,
    output wire                          uart_tx_o
);

    localparam ADDRLSB = 2;

    wire i_reset = !S_AXI_ARESETN;

    wire                            axil_write_ready;
    wire [C_AXI_ADDR_WIDTH-ADDRLSB-1:0] awskd_addr;
    wire [C_AXI_DATA_WIDTH-1:0]     wskd_data;
    wire [C_AXI_DATA_WIDTH/8-1:0]   wskd_strb;
    reg                             axil_bvalid;
    wire                            axil_read_ready;
    wire [C_AXI_ADDR_WIDTH-ADDRLSB-1:0] arskd_addr;
    reg  [C_AXI_DATA_WIDTH-1:0]     axil_read_data;
    reg                             axil_read_valid;

    reg [31:0] UART_PRE, UART_STP, UART_TDR;
    reg [2:0]  UART_CFG;
    wire [31:0] wskd_pre, wskd_stp, wskd_tdr;

    // ----------------------------------------------------------------
    // AXI-lite write channel
    // ----------------------------------------------------------------
    reg axil_awready;

    initial axil_awready = 1'b0;
    always @(posedge S_AXI_ACLK)
        if (i_reset)
            axil_awready <= 1'b0;
        else
            axil_awready <= !axil_awready
                && (S_AXI_AWVALID && S_AXI_WVALID)
                && (!S_AXI_BVALID || S_AXI_BREADY);

    assign S_AXI_AWREADY = axil_awready;
    assign S_AXI_WREADY  = axil_awready;
    assign awskd_addr    = S_AXI_AWADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB];
    assign wskd_data     = S_AXI_WDATA;
    assign wskd_strb     = S_AXI_WSTRB;
    assign axil_write_ready = axil_awready;

    initial axil_bvalid = 0;
    always @(posedge S_AXI_ACLK)
        if (i_reset)
            axil_bvalid <= 0;
        else if (axil_write_ready)
            axil_bvalid <= 1;
        else if (S_AXI_BREADY)
            axil_bvalid <= 0;

    assign S_AXI_BVALID = axil_bvalid;
    assign S_AXI_BRESP  = 2'b00;

    // ----------------------------------------------------------------
    // AXI-lite read channel
    // ----------------------------------------------------------------
    reg axil_arready;

    always @(*) axil_arready = !S_AXI_RVALID;

    assign arskd_addr    = S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB];
    assign S_AXI_ARREADY = axil_arready;
    assign axil_read_ready = (S_AXI_ARVALID && S_AXI_ARREADY);

    initial axil_read_valid = 1'b0;
    always @(posedge S_AXI_ACLK)
        if (i_reset)
            axil_read_valid <= 1'b0;
        else if (axil_read_ready)
            axil_read_valid <= 1'b1;
        else if (S_AXI_RREADY)
            axil_read_valid <= 1'b0;

    assign S_AXI_RVALID = axil_read_valid;
    assign S_AXI_RDATA  = axil_read_data;
    assign S_AXI_RRESP  = 2'b00;

    // ----------------------------------------------------------------
    // Register logic
    // ----------------------------------------------------------------
    assign wskd_pre = apply_wstrb(UART_PRE, wskd_data, wskd_strb);
    assign wskd_stp = apply_wstrb(UART_STP, wskd_data, wskd_strb);
    assign wskd_tdr = apply_wstrb(UART_TDR, wskd_data, wskd_strb);

    reg data_tx_cplt_o;
    reg data_rx_cplt_o;

    // One-cycle pulse resets for the uart submodule's internal flags
    reg data_rx_cplt_rst_pulse;
    reg data_tx_cplt_rst_pulse;

    initial UART_PRE = 0;
    initial UART_STP = 0;
    initial UART_TDR = 0;
    initial UART_CFG = 0;

    always @(posedge S_AXI_ACLK) begin
        if (i_reset) begin
            UART_PRE <= 0;
            UART_STP <= 0;
            UART_TDR <= 0;
            UART_CFG <= 0;
            data_rx_cplt_rst_pulse <= 1'b0;
            data_tx_cplt_rst_pulse <= 1'b0;
        end else begin
            // Default: pulses are off
            data_rx_cplt_rst_pulse <= 1'b0;
            data_tx_cplt_rst_pulse <= 1'b0;

            if (axil_write_ready) begin
                case (awskd_addr)
                    3'b000: UART_PRE <= wskd_pre;
                    3'b001: UART_STP <= wskd_stp;
                    3'b011: UART_TDR <= wskd_tdr;
                    3'b100: begin
                        // Bit 0: tx_enable — written directly
                        UART_CFG[0] <= wskd_data[0];

                        // Bit 1: RX complete — clear when C writes 0
                        if (wskd_data[1] == 1'b0) begin
                            UART_CFG[1] <= 1'b0;
                            data_rx_cplt_rst_pulse <= 1'b1; // pulse to clear uart_rx internal flag
                        end

                        // Bit 2: TX complete — clear when C writes 0
                        if (wskd_data[2] == 1'b0) begin
                            UART_CFG[2] <= 1'b0;
                            data_tx_cplt_rst_pulse <= 1'b1; // pulse to clear uart_tx internal flag
                        end
                    end
                    default: begin end
                endcase
            end

            // Hardware sets RX complete flag
            if (data_rx_cplt_o)
                UART_CFG[1] <= 1'b1;

            // Hardware sets TX complete flag AND auto-clears tx_enable
            // so TX cannot re-fire until C explicitly sets bit 0 again
            if (data_tx_cplt_o) begin
                UART_CFG[2] <= 1'b1;
                UART_CFG[0] <= 1'b0; // ← key: force tx_enable low on completion
            end
        end
    end

    wire [7:0] data_uart_rdr;

    initial axil_read_data = 0;
    always @(posedge S_AXI_ACLK)
        if (OPT_LOWPOWER && !S_AXI_ARESETN)
            axil_read_data <= 0;
        else if (!S_AXI_RVALID || S_AXI_RREADY) begin
            case (arskd_addr)
                3'b000: axil_read_data <= UART_PRE;
                3'b001: axil_read_data <= {30'd0, UART_STP[1:0]};
                3'b010: axil_read_data <= {24'd0, data_uart_rdr};
                3'b011: axil_read_data <= {24'd0, UART_TDR[7:0]};
                3'b100: axil_read_data <= {29'd0,
                                        data_tx_cplt_o,  // bit 2: live signal
                                        data_rx_cplt_o,  // bit 1: live signal
                                        UART_CFG[0]};    // bit 0: tx_enable
                default: axil_read_data <= 0;
            endcase

            if (OPT_LOWPOWER && !axil_read_ready)
                axil_read_data <= 0;
        end

    function [C_AXI_DATA_WIDTH-1:0] apply_wstrb;
        input [C_AXI_DATA_WIDTH-1:0]   prior_data;
        input [C_AXI_DATA_WIDTH-1:0]   new_data;
        input [C_AXI_DATA_WIDTH/8-1:0] wstrb;
        integer k;
        for (k = 0; k < C_AXI_DATA_WIDTH/8; k = k+1)
            apply_wstrb[k*8 +: 8] = wstrb[k] ? new_data[k*8 +: 8] : prior_data[k*8 +: 8];
    endfunction

    wire unused;
    assign unused = &{1'b0, S_AXI_AWPROT, S_AXI_ARPROT,
                      S_AXI_ARADDR[ADDRLSB-1:0],
                      S_AXI_AWADDR[ADDRLSB-1:0]};

    wire data_tx_cplt_w;
    wire data_rx_cplt_w;

    always @(posedge S_AXI_ACLK) begin
        if (i_reset) begin
            data_tx_cplt_o <= 1'b0;
            data_rx_cplt_o <= 1'b0;
        end else begin
            data_tx_cplt_o <= data_tx_cplt_w;
            data_rx_cplt_o <= data_rx_cplt_w;
        end
    end

    uart uart_instance (
        .clk_i              (S_AXI_ACLK),
        .rst_ni             (S_AXI_ARESETN),
        .prescaler_i        (UART_PRE),
        .stop_bit_cfg_i     (UART_STP[1:0]),
        .data_tx_i          (UART_TDR[7:0]),
        .tx_enable_i        (UART_CFG[0]),
        .data_tx_cplt_o     (data_tx_cplt_w),
        .data_tx_cplt_rst_i (data_tx_cplt_rst_pulse),
        .tx_pin_o           (uart_tx_o),
        .data_rx_o          (data_uart_rdr),
        .data_rx_cplt_o     (data_rx_cplt_w),
        .data_rx_cplt_rst_i (data_rx_cplt_rst_pulse),
        .rx_pin_i           (uart_rx_i)
    );

endmodule