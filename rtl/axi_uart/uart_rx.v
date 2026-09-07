module uart_rx (
    input  wire        clk_i,
    input  wire        rst_ni,
    input  wire [31:0] prescaler_i,
    input  wire [31:0] stop_bit_prescaler_i,
    output reg  [7:0]  data_rx_o,
    output reg         data_rx_cplt_o,
    input  wire        data_rx_cplt_rst_i,
    input  wire        rx_pin_i
);

    // 2-stage synchronizer
    reg rx_sync_0, rx_sync_1;

    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rx_sync_0 <= 1'b1;
            rx_sync_1 <= 1'b1;
        end else begin
            rx_sync_0 <= rx_pin_i;
            rx_sync_1 <= rx_sync_0;
        end
    end

    localparam [1:0] IDLE        = 2'd0,
                     RX_START_BIT = 2'd1,
                     RX_DATA_BITS = 2'd2,
                     RX_STOP_BIT  = 2'd3;

    reg [1:0]  state;
    reg [31:0] counter;
    reg [2:0]  bit_index;
    reg [7:0]  rx_data;

    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state          <= IDLE;
            counter        <= 0;
            bit_index      <= 3'b0;
            rx_data        <= 8'b0;
            data_rx_o      <= 8'b0;
            data_rx_cplt_o <= 1'b0;
        end else begin

            if (data_rx_cplt_rst_i)
                data_rx_cplt_o <= 1'b0;

            case (state)

                IDLE: begin
                    bit_index <= 3'b0;
                    counter   <= 32'b0;
                    if (rx_sync_1 == 1'b0)
                        state <= RX_START_BIT;
                end

                RX_START_BIT: begin
                    if (rx_sync_1 == 1'b1) begin
                        counter <= 0;
                        state   <= IDLE;
                    end else if (counter >= (prescaler_i >> 1)) begin
                        counter <= prescaler_i >> 1;
                        state   <= RX_DATA_BITS;
                    end else begin
                        counter <= counter + 1;
                    end
                end

                RX_DATA_BITS: begin
                    if (counter < prescaler_i - 1) begin
                        counter <= counter + 1;
                    end else begin
                        counter            <= 0;
                        rx_data[bit_index] <= rx_sync_1;
                        if (bit_index < 3'd7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state     <= RX_STOP_BIT;
                        end
                    end
                end

                RX_STOP_BIT: begin
                    if (counter < stop_bit_prescaler_i - 1) begin
                        counter <= counter + 1;
                    end else begin
                        counter <= 32'b0;
                        if (rx_sync_1 == 1'b1) begin
                            data_rx_cplt_o <= 1'b1;
                            data_rx_o      <= rx_data;
                        end
                        $display("UART RX Done: 0x%02h ('%c')", rx_data, rx_data);
                        state <= IDLE;
                    end
                end

            endcase
        end
    end

endmodule