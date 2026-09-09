module mdio_master (
    input wire clk_i,
    input wire rst_n,

    input wire start_i,
    input wire rw_i, // 1 for read, 0 for write
    output reg done_o,
    input wire [4:0] phy_addr_i,
    input wire [4:0] reg_addr_i,
    input wire [15:0] reg_value_write_i,
    output reg [15:0] reg_value_read_o,

    output reg mdc_o,
    output wire mdio_o,
    input wire mdio_i,
    output reg mdio_write_o // write 1 to take over write, 0 to read
);

    parameter DIV = 10; // input 50mhz, output 2.5mhz

    reg [7:0] clk_divider_counter;
    reg mdc_rise;
    reg mdc_fall;

    reg mdio_o_r;

    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            clk_divider_counter <= 8'd0;
            mdc_rise <= 1'b0;
            mdc_fall <= 1'b0;
            mdc_o <= 1'b0;
        end else begin
            // default values
            mdc_rise <= 1'b0;
            mdc_fall <= 1'b0;

            if (clk_divider_counter == DIV - 1) begin
                clk_divider_counter <= 8'b0;
                mdc_o <= ~mdc_o;
                if (!mdc_o) begin
                    // mdc is low previously, now high, so its rising edge
                    mdc_rise <= 1'b1;
                end else begin
                    mdc_fall <= 1'b1;
                end
            end else begin
                clk_divider_counter <= clk_divider_counter + 1;
            end
        end
    end

    localparam  IDLE = 4'd0,
                PREAMBLE = 4'd1,
                START_OPCODE_PHY_ADDR_REG_ADDR = 4'd2,
                TA = 4'd3,
                REG_DATA_READ = 4'd4,
                FINISH = 4'd5;
    
    reg [3:0] state;
    reg [31:0] value;
    reg [4:0] bit_cnt;
    reg [15:0] local_reg_value_read;

    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            mdio_write_o <= 1'b1; // always take over during idle, output high during idle
            reg_value_read_o <= 16'b0;
            state <= 4'b0;
            done_o <= 1'b0;
            value <= 32'b0;
            bit_cnt <= 5'b0;
            local_reg_value_read <= 16'd0;
        end else begin
            // done_o <= 1'b0; // dont reset done at here

            case (state)
                IDLE: begin
                    mdio_write_o <= 1'b1;

                    if (start_i) begin
                        if (rw_i) begin
                            // read
                            value <= {2'b01, 2'b10, phy_addr_i, reg_addr_i, 18'b0};
                        end else begin
                            // write
                            value <= {2'b01, 2'b01, phy_addr_i, reg_addr_i, 2'b10, reg_value_write_i};
                        end
                        state <= PREAMBLE;
                        bit_cnt <= 5'd31;
                        done_o <= 1'b0;
                    end
                end

                PREAMBLE: begin
                    if (mdc_fall) begin
                        mdio_write_o <= 1'b1;
                        if (bit_cnt == 5'd0) begin
                            bit_cnt <= rw_i ? 5'd13 : 5'd31;
                            state <= START_OPCODE_PHY_ADDR_REG_ADDR;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                START_OPCODE_PHY_ADDR_REG_ADDR: begin
                    if (mdc_fall) begin
                        value <= {value[30:0], 1'b0};

                        if (bit_cnt == 5'd0) begin
                            if (rw_i) begin
                                mdio_write_o <= 1'b0;
                                bit_cnt <= 5'd1;
                                state <= TA;
                            end else begin
                                state <= FINISH;
                            end
                        end else begin
                            mdio_write_o <= 1'b1;
                            bit_cnt <= bit_cnt - 1;
                        end
                    end
                end

                // TA: begin
                //     if (mdc_fall) begin
                //         mdio_write_o <= 1'b0;

                //         if (bit_cnt == 5'd0) begin
                //             bit_cnt <= 5'd15;
                //             state <= REG_DATA_READ;
                //         end else begin
                //             bit_cnt <= bit_cnt - 1; // reset bit_cnt before entering the reading stage
                //         end
                //     end
                // end
                TA: begin
                    if (mdc_fall) begin
                        mdio_write_o <= 1'b0;
                        if (bit_cnt != 5'd0) begin
                            bit_cnt <= bit_cnt - 1;
                        end else begin
                            // transition on fall, so next rise is fresh bit 15
                            bit_cnt <= 5'd15;
                            state <= REG_DATA_READ;
                        end
                    end
                end       


                REG_DATA_READ: begin
                    if (mdc_rise) begin
                        local_reg_value_read[bit_cnt] <= mdio_i;
                        if (bit_cnt == 5'd0) begin
                            reg_value_read_o <= {local_reg_value_read[15:1], mdio_i};
                            state <= FINISH;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end

                end

                FINISH: begin
                    if (mdc_fall) begin
                        mdio_write_o <= 1'b1;
                    end

                    if (mdc_rise) begin
                        done_o <= 1'b1;
                        state <= IDLE;
                    end
                    
                end

                default: begin
                    
                end

            endcase
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                mdio_o_r = 1'b1;
            end

            PREAMBLE: begin
                mdio_o_r = 1'b1;
            end

            START_OPCODE_PHY_ADDR_REG_ADDR: begin
                mdio_o_r = value[31];
            end

            TA: begin
                mdio_o_r = 1'b1; // its ok, because the line is now held my phy
            end

            FINISH: begin
                mdio_o_r = 1'b1;
            end

            default: begin
                mdio_o_r = 1'b1;
            end
        endcase
    end

    assign mdio_o = mdio_o_r;

endmodule
