module uart (
    input  wire        clk_i,
    input  wire        rst_ni,
    input  wire [31:0] prescaler_i,
    input  wire [1:0]  stop_bit_cfg_i,

    input  wire [7:0]  data_tx_i,
    input  wire        tx_enable_i,
    output wire        data_tx_cplt_o,
    input  wire        data_tx_cplt_rst_i,
    output wire        tx_pin_o,

    output wire [7:0]  data_rx_o,
    output wire        data_rx_cplt_o,
    input  wire        data_rx_cplt_rst_i,
    input  wire        rx_pin_i
);

    reg [31:0] stop_bit_prescaler;

    always @(*) begin
        case (stop_bit_cfg_i)
            2'b00:   stop_bit_prescaler = prescaler_i;
            2'b01:   stop_bit_prescaler = prescaler_i + (prescaler_i >> 1);
            default: stop_bit_prescaler = prescaler_i << 1;
        endcase
    end

    wire tx_cplt_w;
    wire tx_pin_w;
    wire [7:0] rx_data_w;
    wire rx_cplt_w;

    assign data_tx_cplt_o = tx_cplt_w;
    assign tx_pin_o       = tx_pin_w;
    assign data_rx_o      = rx_data_w;
    assign data_rx_cplt_o = rx_cplt_w;

    uart_tx tx (
        .clk_i               (clk_i),
        .rst_ni              (rst_ni),
        .prescaler_i         (prescaler_i),
        .stop_bit_prescaler_i(stop_bit_prescaler),
        .data_tx_i           (data_tx_i),
        .tx_enable_i         (tx_enable_i),
        .data_tx_cplt_o      (tx_cplt_w),
        .data_tx_cplt_rst_i  (data_tx_cplt_rst_i),
        .tx_pin_o            (tx_pin_w)
    );

    uart_rx rx (
        .clk_i               (clk_i),
        .rst_ni              (rst_ni),
        .prescaler_i         (prescaler_i),
        .stop_bit_prescaler_i(stop_bit_prescaler),
        .data_rx_o           (rx_data_w),
        .data_rx_cplt_o      (rx_cplt_w),
        .data_rx_cplt_rst_i  (data_rx_cplt_rst_i),
        .rx_pin_i            (rx_pin_i)
    );

endmodule