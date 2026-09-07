module uart_tx (
    input  wire        clk_i,
    input  wire        rst_ni,
    input  wire [31:0] prescaler_i,
    input  wire [31:0] stop_bit_prescaler_i,
    input  wire [7:0]  data_tx_i,
    input  wire        tx_enable_i,
    output reg         data_tx_cplt_o,
    input  wire        data_tx_cplt_rst_i,
    output reg         tx_pin_o
);

    localparam [1:0] IDLE         = 2'd0,
                     TX_START_BIT = 2'd1,
                     TX_DATA_BITS = 2'd2,
                     TX_STOP_BIT  = 2'd3;

    reg [1:0]  state;
    reg [31:0] counter;
    reg [2:0]  bit_index;
    reg [7:0]  tx_data;
    reg        tx_fired;

    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state          <= IDLE;
            counter        <= 0;
            data_tx_cplt_o <= 1'b0;
            tx_pin_o       <= 1'b1;
            tx_fired       <= 1'b0;
        end else begin

            if (data_tx_cplt_rst_i) begin
                data_tx_cplt_o <= 1'b0;
                tx_fired       <= 1'b0;
            end

            case (state)
                IDLE: begin
                    counter   <= 32'd0;
                    bit_index <= 3'd0;
                    tx_pin_o  <= 1'b1;
                    if (tx_enable_i && !tx_fired && !data_tx_cplt_o) begin
                        tx_data  <= data_tx_i;
                        tx_fired <= 1'b1;
                        state    <= TX_START_BIT;
                    end
                end

                TX_START_BIT: begin
                    tx_pin_o <= 1'b0;
                    if (counter < prescaler_i - 1)
                        counter <= counter + 1;
                    else begin
                        counter <= 0;
                        state   <= TX_DATA_BITS;
                    end
                end

                TX_DATA_BITS: begin
                    tx_pin_o <= tx_data[bit_index];
                    if (counter < prescaler_i - 1)
                        counter <= counter + 1;
                    else begin
                        counter <= 32'b0;
                        if (bit_index < 3'd7)
                            bit_index <= bit_index + 1;
                        else begin
                            bit_index <= 0;
                            state     <= TX_STOP_BIT;
                        end
                    end
                end

                TX_STOP_BIT: begin
                    tx_pin_o <= 1'b1;
                    if (counter < stop_bit_prescaler_i - 1)
                        counter <= counter + 1;
                    else begin
                        counter        <= 0;
                        data_tx_cplt_o <= 1'b1;
                        $display("UART TX Done: 0x%02h ('%c')", tx_data, tx_data);
                        state          <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule