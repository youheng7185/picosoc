module axi_qspi_nor #(
    parameter C_AXI_ADDR_WIDTH = 6,
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

    // QSPI NOR physical pins
    output wire  cs_n_o,
    input  wire  miso_i,
    output wire  mosi_o,
    output wire  spi_clk_o,
    output wire  spi_clk_en,
    output wire  spi_clk_divided
);

    localparam ADDRLSB = 2;

    // -------------------------------------------------------------------------
    // Register addresses (word-addressed, drop bottom 2 bits)
    // 0x00  CTRL      start[0], data_dir[1], has_address[2],
    //                 data_mode[4:3], dummy_cnt[9:5]
    // 0x04  STATUS    done[0], tx_fifo_empty[1], tx_fifo_full[2],
    //                 rx_fifo_empty[3], rx_fifo_full[4]
    // 0x08  INSTR     instr[7:0]
    // 0x0C  ADDR      addr[31:0]
    // 0x10  DATA_CNT  data_cnt[7:0]
    // 0x14  DATA      FIFO read/write port
    // -------------------------------------------------------------------------
    localparam ADDR_CTRL     = 4'd0,   // 0x00 >> 2
               ADDR_STATUS   = 4'd1,   // 0x04 >> 2
               ADDR_INSTR    = 4'd2,   // 0x08 >> 2
               ADDR_ADDR     = 4'd3,   // 0x0C >> 2
               ADDR_DATA_CNT = 4'd4,   // 0x10 >> 2
               ADDR_DATA     = 4'd5;   // 0x14 >> 2

    wire i_reset = !S_AXI_ARESETN;

    // -------------------------------------------------------------------------
    // AXI-Lite write channel  (identical pattern to axi_nand)
    // -------------------------------------------------------------------------
    reg                           aw_latched;
    reg  [C_AXI_ADDR_WIDTH-1:0]  aw_addr_lat;
    reg                           w_latched;
    reg  [C_AXI_DATA_WIDTH-1:0]  w_data_lat;
    reg  [C_AXI_DATA_WIDTH/8-1:0] w_strb_lat;
    reg                           axil_awready;
    reg                           axil_wready_r;
    reg                           axil_bvalid;

    wire axil_write_ready = aw_latched && w_latched;
    wire [C_AXI_ADDR_WIDTH-ADDRLSB-1:0] awskd_addr;
    wire [C_AXI_DATA_WIDTH-1:0]          wskd_data;
    wire [C_AXI_DATA_WIDTH/8-1:0]        wskd_strb;

    assign awskd_addr = aw_addr_lat[C_AXI_ADDR_WIDTH-1:ADDRLSB];
    assign wskd_data  = w_data_lat;
    assign wskd_strb  = w_strb_lat;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            aw_latched  <= 0;
            aw_addr_lat <= 0;
        end else if (S_AXI_AWVALID && S_AXI_AWREADY) begin
            aw_addr_lat <= S_AXI_AWADDR;
            aw_latched  <= 1;
        end else if (axil_write_ready) begin
            aw_latched  <= 0;
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            axil_awready <= 0;
        else
            axil_awready <= !aw_latched && !S_AXI_AWREADY;
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            w_latched  <= 0;
            w_data_lat <= 0;
            w_strb_lat <= 0;
        end else if (S_AXI_WVALID && S_AXI_WREADY) begin
            w_data_lat <= S_AXI_WDATA;
            w_strb_lat <= S_AXI_WSTRB;
            w_latched  <= 1;
        end else if (axil_write_ready) begin
            w_latched  <= 0;
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            axil_wready_r <= 0;
        else
            axil_wready_r <= !w_latched && !S_AXI_WREADY;
    end

    always @(posedge S_AXI_ACLK) begin
        if (i_reset)
            axil_bvalid <= 0;
        else if (axil_write_ready)
            axil_bvalid <= 1;
        else if (S_AXI_BREADY)
            axil_bvalid <= 0;
    end

    assign S_AXI_AWREADY = axil_awready;
    assign S_AXI_WREADY  = axil_wready_r;
    assign S_AXI_BVALID  = axil_bvalid;
    assign S_AXI_BRESP   = 2'b00;

    // -------------------------------------------------------------------------
    // AXI-Lite read channel
    // -------------------------------------------------------------------------
    wire [C_AXI_ADDR_WIDTH-ADDRLSB-1:0] arskd_addr;
    assign arskd_addr = S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB];

    wire axil_read_ready = S_AXI_ARVALID && S_AXI_ARREADY;

    reg axil_arready_r;
    reg axil_read_valid;
    reg [C_AXI_DATA_WIDTH-1:0] axil_read_data;

    // Two-cycle FIFO read pipeline (same as axi_nand)
    reg fifo_rd_en_r;
    reg fifo_rd_pending;
    reg fifo_read_in_progress;

    wire tx_fifo_empty, tx_fifo_full;   // TX FIFO: NOR controller → AXI master

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            fifo_rd_en_r          <= 1'b0;
            fifo_rd_pending       <= 1'b0;
            fifo_read_in_progress <= 1'b0;
        end else begin
            fifo_rd_en_r    <= 1'b0;
            fifo_rd_pending <= fifo_rd_en_r;

            if (axil_read_ready && (arskd_addr == ADDR_DATA)) begin
                fifo_rd_en_r          <= 1'b1;
                fifo_read_in_progress <= 1'b1;
            end

            if (fifo_rd_pending) begin
                fifo_read_in_progress <= 1'b0;
            end
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axil_arready_r <= 1'b0;
        end else begin
            axil_arready_r <= !S_AXI_RVALID && !fifo_read_in_progress;
            if (S_AXI_ARVALID && axil_arready_r)
                axil_arready_r <= 1'b0;
        end
    end

    wire [31:0] tx_fifo_dout;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axil_read_valid <= 1'b0;
            axil_read_data  <= 32'b0;
        end else if (fifo_rd_pending) begin
            // Data from TX FIFO is ready one cycle after rd_en
            axil_read_valid <= 1'b1;
            axil_read_data  <= tx_fifo_dout;
        end else if (axil_read_ready && (arskd_addr != ADDR_DATA)) begin
            axil_read_valid <= 1'b1;
            case (arskd_addr)
                ADDR_CTRL: axil_read_data <= 32'b0; // write-only
                ADDR_STATUS: axil_read_data <= {
                    27'b0,
                    rx_fifo_full,    // [4] RX FIFO (master→NOR) full
                    rx_fifo_empty,   // [3] RX FIFO (master→NOR) empty
                    tx_fifo_full,    // [2] TX FIFO (NOR→master) full
                    tx_fifo_empty,   // [1] TX FIFO (NOR→master) empty
                    nor_done         // [0] transaction done
                };
                ADDR_INSTR:    axil_read_data <= {24'b0, reg_instr};
                ADDR_ADDR:     axil_read_data <= reg_addr;
                ADDR_DATA_CNT: axil_read_data <= {24'b0, reg_data_cnt};
                default:       axil_read_data <= 32'b0;
            endcase
        end else if (axil_read_valid && S_AXI_RREADY) begin
            axil_read_valid <= 1'b0;
        end
    end

    assign S_AXI_ARREADY = axil_arready_r;
    assign S_AXI_RVALID  = axil_read_valid;
    assign S_AXI_RDATA   = axil_read_data;
    assign S_AXI_RRESP   = 2'b00;

    // -------------------------------------------------------------------------
    // Control registers
    // -------------------------------------------------------------------------
    reg        ctrl_start;
    reg        reg_data_dir;       // 0=read from NOR, 1=write to NOR
    reg        reg_has_address;
    reg [1:0]  reg_data_mode;      // 00=no data, 01=transfer data_cnt bytes
    reg [4:0]  reg_dummy_cnt;
    reg [7:0]  reg_instr;
    reg [31:0] reg_addr;
    reg [7:0]  reg_data_cnt;

    wire nor_done;

    // RX FIFO: AXI master → NOR controller  (data to write to flash)
    reg         rx_fifo_wr_en;
    reg  [31:0] rx_fifo_din;
    wire        rx_fifo_full;
    wire        rx_fifo_empty;

    always @(posedge S_AXI_ACLK) begin
        if (i_reset) begin
            ctrl_start      <= 1'b0;
            reg_data_dir    <= 1'b0;
            reg_has_address <= 1'b0;
            reg_data_mode   <= 2'b00;
            reg_dummy_cnt   <= 5'd0;
            reg_instr       <= 8'd0;
            reg_addr        <= 32'd0;
            reg_data_cnt    <= 8'd0;
            rx_fifo_wr_en   <= 1'b0;
            rx_fifo_din     <= 32'd0;
        end else begin
            rx_fifo_wr_en <= 1'b0; // self-clear

            if (axil_write_ready) begin
                case (awskd_addr)
                    ADDR_CTRL: begin
                        // Bit layout:
                        //  [0]     start
                        //  [1]     data_dir   (0=read NOR, 1=write NOR)
                        //  [2]     has_address
                        //  [4:3]   data_mode
                        //  [9:5]   dummy_cnt
                        ctrl_start      <= wskd_data[0];
                        reg_data_dir    <= wskd_data[1];
                        reg_has_address <= wskd_data[2];
                        reg_data_mode   <= wskd_data[4:3];
                        reg_dummy_cnt   <= wskd_data[9:5];
                    end
                    ADDR_INSTR:    reg_instr    <= wskd_data[7:0];
                    ADDR_ADDR:     reg_addr     <= wskd_data;
                    ADDR_DATA_CNT: reg_data_cnt <= wskd_data[7:0];
                    ADDR_DATA: begin
                        if (!rx_fifo_full) begin
                            rx_fifo_wr_en <= 1'b1;
                            rx_fifo_din   <= wskd_data;
                        end
                    end
                    default: ;
                endcase
            end
        end
    end

    // -------------------------------------------------------------------------
    // qspi_nor_master instance
    // -------------------------------------------------------------------------
    // Port name mapping vs qspi_nor_master:
    //   TX FIFO (controller → AXI master, i.e. NOR read data):
    //     tx_fifo_rd_en      ← fifo_rd_en_r   (AXI read channel pulls data out)
    //     tx_fifo_data_dout  → tx_fifo_dout
    //     tx_fifo_data_full  → tx_fifo_full
    //     tx_fifo_data_empty → tx_fifo_empty
    //   RX FIFO (AXI master → controller, i.e. NOR write data):
    //     rx_fifo_data_wr_en ← rx_fifo_wr_en
    //     rx_fifo_data_din   ← rx_fifo_din
    //     rx_fifo_data_full  → rx_fifo_full
    //     rx_fifo_data_empty → rx_fifo_empty
    // -------------------------------------------------------------------------
    qspi_nor_master u_qspi_nor_master (
        .clk_i              (S_AXI_ACLK),
        .rst_n              (S_AXI_ARESETN),

        .cs_n_o             (cs_n_o),
        .miso_i             (miso_i),
        .mosi_o             (mosi_o),
        .spi_clk_o          (spi_clk_o),
        .clk_out_en_o       (spi_clk_en),
        .clk_o_o            (spi_clk_divided),

        .start_i            (ctrl_start),
        .done_o             (nor_done),

        .instr_i            (reg_instr),
        .dummy_cnt_i        (reg_dummy_cnt),
        .data_mode_i        (reg_data_mode),
        .data_cnt_i         (reg_data_cnt),
        .has_address_i      (reg_has_address),
        .data_dir_i         (reg_data_dir),

        .addr_i             (reg_addr),

        // TX FIFO: NOR controller → AXI master (read data from flash)
        .tx_fifo_rd_en      (fifo_rd_en_r),
        .tx_fifo_data_dout  (tx_fifo_dout),
        .tx_fifo_data_full  (tx_fifo_full),
        .tx_fifo_data_empty (tx_fifo_empty),

        // RX FIFO: AXI master → NOR controller (write data to flash)
        .rx_fifo_data_wr_en (rx_fifo_wr_en),
        .rx_fifo_data_din   (rx_fifo_din),
        .rx_fifo_data_full  (rx_fifo_full),
        .rx_fifo_data_empty (rx_fifo_empty)
    );

    // -------------------------------------------------------------------------
    // Unused signal tie-off for linting
    // -------------------------------------------------------------------------
    wire unused;
    assign unused = &{1'b0, S_AXI_AWPROT, S_AXI_ARPROT,
                      S_AXI_ARADDR[ADDRLSB-1:0],
                      S_AXI_AWADDR[ADDRLSB-1:0],
                      wskd_strb};

endmodule