module qspi_nor_master (
    input wire clk_i,
    input wire rst_n,

    output reg cs_n_o,
    input wire miso_i,
    output reg mosi_o,
    output wire spi_clk_o,
    output wire clk_out_en_o,
    output wire clk_o_o,

    input wire start_i,
    output reg done_o,

    input wire [7:0] instr_i,
    // input wire rd_wr_i, // 1 for read, 0 for write
    input wire [4:0] dummy_cnt_i,
    input wire [1:0] data_mode_i, // 00 for not sending data, 01 to transmit based on data_cnt_i
    input wire [7:0] data_cnt_i, // write 0 for 1 byte to send
    input wire has_address_i, // 1 for has address
    input wire data_dir_i, // data direction, 0 to read from flash, 1 to write to flash

    input wire [31:0] addr_i, // 4 byte or 3 byte addr
    
    // tx out to master
    input wire tx_fifo_rd_en,
    output wire [31:0] tx_fifo_data_dout,
    output wire tx_fifo_data_full,
    output wire tx_fifo_data_empty,

    // rx from master
    input wire rx_fifo_data_wr_en,
    input wire [31:0] rx_fifo_data_din,
    output wire rx_fifo_data_full,
    output wire rx_fifo_data_empty
);

    // parameter DIV = 10; // input 50mhz, output 2.5mhz
    parameter DIV = 2;

    reg [7:0] clk_divider_counter;
    reg clk_rise;
    reg clk_fall;
    reg clk_o;
    assign clk_o_o = clk_o;

    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            clk_divider_counter <= 8'd0;
            clk_rise <= 1'b0;
            clk_fall <= 1'b0;
            clk_o <= 1'b0;
        end else begin
            // default values
            clk_rise <= 1'b0;
            clk_fall <= 1'b0;

            if (clk_divider_counter == DIV - 1) begin
                clk_divider_counter <= 8'b0;
                clk_o <= ~clk_o;
                if (!clk_o) begin
                    // clk is low previously, now high, so its rising edge
                    clk_rise <= 1'b1;
                end else begin
                    clk_fall <= 1'b1;
                end
            end else begin
                clk_divider_counter <= clk_divider_counter + 1;
            end
        end
    end

    wire fifo_data_wr_en;
    reg [31:0] fifo_data_wr;

    // master reading this, controller writes to here, NAND controller -> master
    fifo u_tx_fifo (
        .clk_i(clk_i),
        .rst_n(rst_n),
        .wr_en(fifo_data_wr_en),
        .rd_en(tx_fifo_rd_en),
        .din(fifo_data_wr),
        .dout(tx_fifo_data_dout),
        .full_o(tx_fifo_data_full),
        .empty_o(tx_fifo_data_empty)
    );
    
    wire fifo_data_rd_en;
    wire [31:0] fifo_data_rd;

    // controller reading this, master writes to here, master -> NAND controller
    fifo u_rx_fifo (
        .clk_i(clk_i),
        .rst_n(rst_n),
        .wr_en(rx_fifo_data_wr_en),
        .rd_en(fifo_data_rd_en),
        .din(rx_fifo_data_din),
        .dout(fifo_data_rd),
        .full_o(rx_fifo_data_full),
        .empty_o(rx_fifo_data_empty)
    );

    reg clk_out_en;
    assign clk_out_en_o = clk_out_en;
    assign spi_clk_o = clk_o && clk_out_en;
    reg [7:0] counter_clk_rise;
    reg [7:0] counter_clk_fall;
    reg [7:0] counter_data_flow;

    // fifo for storing data of page write
    reg [7:0] data_to_write [0:3];

    localparam FIFO_IDLE       = 4'd0,
                FIFO_RECEIVE_FETCH_SIGNAL    = 4'd1,
                FIFO_DEASSERT_READ_REQUEST   = 4'd2,
                FIFO_WRITE_INTO_DATA_TO_WRITE   = 4'd3,
                FIFO_WRITE_DONE   = 4'd4;

    reg [3:0] fifo_state;
    reg fifo_rd_req;
    reg fifo_rd_req_set;
    assign fifo_data_rd_en = fifo_rd_req;

    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            fifo_rd_req <= 1'b0;
            fifo_state <= FIFO_IDLE;
        end else begin
            case (fifo_state)
                FIFO_IDLE: begin
                    if (fifo_rd_req_set) begin
                        fifo_state <= FIFO_RECEIVE_FETCH_SIGNAL;
                    end
                end

                FIFO_RECEIVE_FETCH_SIGNAL: begin
                    fifo_rd_req <= 1'b1;
                    fifo_state <= FIFO_DEASSERT_READ_REQUEST;
                end

                FIFO_DEASSERT_READ_REQUEST: begin
                    fifo_rd_req <= 1'b0;
                    fifo_state <= FIFO_WRITE_INTO_DATA_TO_WRITE;
                end

                FIFO_WRITE_INTO_DATA_TO_WRITE: begin
                    data_to_write[0] <= fifo_data_rd[7:0];
                    data_to_write[1] <= fifo_data_rd[15:8];
                    data_to_write[2] <= fifo_data_rd[23:16];
                    data_to_write[3] <= fifo_data_rd[31:24];
                    fifo_state <= FIFO_WRITE_DONE;
                end

                FIFO_WRITE_DONE: begin
                    if (!fifo_rd_req_set) begin
                        // the main fsm should release this signals afterwards
                        fifo_state <= FIFO_IDLE;
                    end
                end
                
                default: begin
                    $display("shouldnt reach here for fifo");
                end
            endcase
        end
    end

    localparam IDLE       = 5'd0,
                CS_N_ASSERT = 5'd1,
                SEND_CMD = 5'd2,
                SEND_ADDRESS = 5'd3,
                SEND_DUMMY = 5'd4,
                SEND_DATA = 5'd5,
                READ_DATA_PRE = 5'd6,
                READ_DATA = 5'd7,
                PULL_DOWN_CS_BEFORE_DONE = 5'd8,
                DONE = 5'd9;

    reg [4:0] state;
    reg do_fifo_write;
    reg [31:0] read_data_reg_for_fifo_input;

    assign fifo_data_wr_en = do_fifo_write && clk_fall && !tx_fifo_data_full;

    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            clk_out_en <= 1'b0;
            cs_n_o <= 1'b1;
            counter_clk_rise <= 8'd0;
            counter_clk_fall <= 8'd0;
            done_o <= 1'b0;
            mosi_o <= 1'b0;
            counter_data_flow <= 8'd0;
            do_fifo_write <= 1'b0;
            read_data_reg_for_fifo_input <= 32'b0;
        end else begin
            /*
                Write stuff to do during rising edge here
            */
            if (clk_rise) begin
                case (state) 
                    IDLE: begin
                        clk_out_en <= 1'b0;
                        cs_n_o <= 1'b1;
                        counter_clk_rise <= 8'b0;
                        done_o <= 1'b0;
                        read_data_reg_for_fifo_input <= 32'b0;

                        if (start_i) begin
                            state <= CS_N_ASSERT;
                            counter_clk_rise <= 8'd0; // dont toggle clk, let cs_n stable

                            if (data_mode_i == 2'b01 && data_dir_i == 1'b1) begin
                                fifo_rd_req_set <= 1'b1; // fetch data from fifo, prepare data first
                            end
                        end
                    end

                    CS_N_ASSERT: begin
                        cs_n_o <= 1'b0;
                        if (counter_clk_rise == 8'd0) begin
                            state <= SEND_CMD;
                            counter_clk_rise <= 8'd7;
                            counter_clk_fall <= 8'd7;
                            counter_data_flow <= 8'd0;
                        end else begin
                            counter_clk_rise <= counter_clk_rise - 1;
                        end
                    end

                    READ_DATA: begin
                        read_data_reg_for_fifo_input[counter_clk_rise[4:0] + (counter_data_flow[1:0] << 3)] <= miso_i;
                        
                        if (counter_clk_rise == 8'd0) begin
                            counter_clk_rise <= 8'd7;
                            // $display("miso_i value: %d", miso_i);
                            // $display("current reg: 0x%x", read_data_reg_for_fifo_input);
                        end else begin
                            // $display("miso_i value: %d", miso_i);
                            counter_clk_rise <= counter_clk_rise - 1;
                        end
                    end

                    DONE: begin
                        cs_n_o <= 1'b1;
                        done_o <= 1'b1;
                        if (start_i == 1'b0) begin
                            state <= IDLE;
                        end
                    end

                    default: begin
                        
                    end
                endcase
            /*
                Write stuff to do during falling edge here
            */
            end if (clk_fall) begin
                case (state) 
                    SEND_CMD: begin
                        clk_out_en <= 1'b1;
                        mosi_o <= instr_i[counter_clk_fall[2:0]];
                        if (counter_clk_fall == 8'd0) begin
                            if (has_address_i == 1'b1) begin
                                state <= SEND_ADDRESS;
                                counter_clk_fall <= 8'd23;  // fixme
                            end else if (data_mode_i == 2'b01) begin
                                if (data_dir_i == 1'b1) begin
                                    state <= SEND_DATA;
                                end else begin
                                    state <= READ_DATA_PRE; // idk?
                                end

                                counter_clk_fall <= 8'd7;
                                counter_data_flow <= 8'd0;
                            end else begin
                                state <= PULL_DOWN_CS_BEFORE_DONE;
                            end
                        end else begin
                            counter_clk_fall <= counter_clk_fall - 1;
                        end
                    end

                    SEND_ADDRESS: begin
                        mosi_o <= addr_i[counter_clk_fall[4:0]];
                        if (counter_clk_fall == 8'd0) begin
                            if (data_mode_i == 2'b01) begin
                                // has data to send
                                if (dummy_cnt_i == 5'b0) begin
                                    if (data_dir_i == 1'b1) begin
                                        state <= SEND_DATA;
                                    end else begin
                                        // state <= READ_DATA;
                                        state <= READ_DATA_PRE;
                                    end
                                    counter_clk_fall <= 8'd7;
                                    counter_data_flow <= 8'd0;
                                end else begin
                                    state <= SEND_DUMMY;
                                    counter_clk_fall <= dummy_cnt_i - 1;
                                end
                            end else if (data_mode_i == 2'b00) begin
                                // no data to transfer after address
                                state <= PULL_DOWN_CS_BEFORE_DONE;
                            end
                        end else begin
                            counter_clk_fall <= counter_clk_fall - 1;
                        end
                    end

                    SEND_DUMMY: begin
                        if (counter_clk_fall == 8'd0) begin
                            state <= READ_DATA;
                            counter_clk_fall <= 8'd7;
                        end else begin
                            counter_clk_fall <= counter_clk_fall - 1;
                        end
                    end

                    READ_DATA_PRE: begin
                        state <= READ_DATA;
                    end

                    SEND_DATA: begin
                        mosi_o <= data_to_write[counter_data_flow[1:0]][counter_clk_fall[2:0]];

                        if (counter_clk_fall == 8'd0) begin
                            if (counter_data_flow == data_cnt_i) begin
                                fifo_rd_req_set <= 1'b0;
                                state <= PULL_DOWN_CS_BEFORE_DONE;
                            end else begin
                                // fetch another cycle of fifo
                                if (counter_data_flow[1:0] == 2'b11) begin
                                    if (!rx_fifo_data_empty) begin
                                        counter_clk_fall <= 8'd7;
                                        counter_data_flow <= counter_data_flow + 1;
                                        fifo_rd_req_set <= 1'b1;
                                        clk_out_en <= 1'b1;
                                    end else begin
                                        clk_out_en <= 1'b0;
                                        $display("fifo is empty, please fill up from master");
                                    end
                                end else begin
                                        fifo_rd_req_set <= 1'b0;
                                        counter_clk_fall <= 8'd7;
                                        counter_data_flow <= counter_data_flow + 1;                                     
                                    end
                                end
                            
                        end else begin
                            fifo_rd_req_set <= 1'b0;
                            counter_clk_fall <= counter_clk_fall - 1;
                        end
                    end

                    READ_DATA: begin
                        do_fifo_write <= 1'b0;

                        if (counter_clk_fall == 8'd0) begin
                            counter_clk_fall <= 8'd7;
                            counter_data_flow <= counter_data_flow + 1;
                            // read_data_reg_for_fifo_input <= {read_data_reg_for_fifo_input[23:0], 8'b0};

                            if (counter_data_flow == data_cnt_i) begin
                                state <= PULL_DOWN_CS_BEFORE_DONE;
                                do_fifo_write <= 1'b1;
                                fifo_data_wr <= read_data_reg_for_fifo_input;
                            end else if (counter_data_flow[1:0] == 2'b11) begin
                                    // four byte collected
                                    do_fifo_write <= 1'b1;
                                    fifo_data_wr <= read_data_reg_for_fifo_input;
                                    read_data_reg_for_fifo_input <= 32'b0;
                            end

                        end else begin
                            counter_clk_fall <= counter_clk_fall - 1;
                        end

                    end

                    PULL_DOWN_CS_BEFORE_DONE: begin
                        cs_n_o <= 1'b0;
                        clk_out_en <= 1'b0;
                        do_fifo_write <= 1'b0;
                        state <= DONE;
                    end

                    default: begin
                        
                    end
                endcase
            end
        end
    end

endmodule