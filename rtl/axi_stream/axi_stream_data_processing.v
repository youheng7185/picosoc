module axi_stream_data_processing # (
    parameter integer C_M_AXIS_TDATA_WIDTH	= 32,
    parameter integer C_S_AXIS_TDATA_WIDTH	= 32,
    parameter integer C_M_START_COUNT	= 32
)(
    input wire clk_i,
    input wire rst_n,

    // axi stream slave, data in
    // Ready to accept data in
    output wire  S_AXIS_TREADY,
    // Data in
    input wire [C_S_AXIS_TDATA_WIDTH-1 : 0] S_AXIS_TDATA,
    // Byte qualifier
    input wire [(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] S_AXIS_TSTRB,
    // Indicates boundary of last packet
    input wire  S_AXIS_TLAST,
    // Data is in valid
    input wire  S_AXIS_TVALID,

    // axi stream master, data out
    // Master Stream Ports. TVALID indicates that the master is driving a valid transfer, A transfer takes place when both TVALID and TREADY are asserted. 
    output wire  M_AXIS_TVALID,
    // TDATA is the primary payload that is used to provide the data that is passing across the interface from the master.
    output wire [C_M_AXIS_TDATA_WIDTH-1 : 0] M_AXIS_TDATA,
    // TSTRB is the byte qualifier that indicates whether the content of the associated byte of TDATA is processed as a data byte or a position byte.
    output wire [(C_M_AXIS_TDATA_WIDTH/8)-1 : 0] M_AXIS_TSTRB,
    // TLAST indicates the boundary of a packet.
    output wire  M_AXIS_TLAST,
    // TREADY indicates that the slave can accept a transfer in the current cycle.
    input wire  M_AXIS_TREADY,

    output reg data_all_processed
);

    localparam NUMBER_OF_INPUT_WORDS = 8;
    localparam NUMBER_OF_OUTPUT_WORDS = 8;
    reg [31:0] data_in_reg [0:7];
    reg [31:0] data_out_reg [0:7];

    parameter [1:0] DATA_IN_IDLE = 2'd0,
                    DATA_IN_WRITE = 2'd1,
                    DATA_DONT_ACCEPT = 2'd2;
    
    reg [1:0] mst_s_exec_state;
    reg data_all_received;

    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            mst_s_exec_state <= DATA_IN_IDLE;
        end else begin
            case (mst_s_exec_state)
                DATA_IN_IDLE: begin
                    if (S_AXIS_TVALID) begin
                        mst_s_exec_state <= DATA_IN_WRITE;
                    end
                end

                DATA_IN_WRITE: begin
                    if (data_all_received) begin
                        mst_s_exec_state <= DATA_DONT_ACCEPT;
                    end else begin
                        // continue accepts data in
                        mst_s_exec_state <= DATA_IN_WRITE;
                    end
                end

                DATA_DONT_ACCEPT: begin
                    if (data_all_processed) begin
                        mst_s_exec_state <= DATA_IN_IDLE;
                    end
                end

            endcase
        end
    end

    reg [7:0] write_ptr;
    assign axis_tready = ((mst_s_exec_state == DATA_IN_WRITE) && (write_ptr <= NUMBER_OF_INPUT_WORDS-1));
    assign fifo_wren = S_AXIS_TVALID && axis_tready;
    assign S_AXIS_TREADY	= axis_tready;

    // update pointer and raise complete flag
    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= 8'd0;
            data_all_received <= 1'b0;
        end else begin
            if ((write_ptr <= NUMBER_OF_INPUT_WORDS - 1) || S_AXIS_TLAST) begin // 8 group of four bytes to receive
                if (fifo_wren) begin
                    write_ptr <= write_ptr + 1;
                    data_all_received <= 1'b0;
                end

                if ((write_ptr == NUMBER_OF_INPUT_WORDS - 1) || S_AXIS_TLAST) begin
                    data_all_received <= 1'b1;
                end
            end

            if (data_all_processed) begin
                data_all_received <= 1'b0;
                write_ptr <= 8'd0;
            end
        end
    end

    // async to write into data_in fifo
    always @(posedge clk_i or negedge rst_n) begin
        if (fifo_wren) begin
            data_in_reg[write_ptr[2:0]] <= S_AXIS_TDATA; 
            // i ignore data masking because i dont need it
            $display("writing 0x%x into input data", S_AXIS_TDATA);
        end
    end

    reg [1:0] mst_m_exec_state;
    parameter [1:0] DATA_OUT_IDLE = 2'd0,
                    DATA_OUT_WRITE = 2'd1;
    reg tx_done;
    reg [7:0] read_ptr;

    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            mst_m_exec_state <= DATA_OUT_IDLE;
            tx_done_deassert <= 1'b0;
        end else begin
            case (mst_m_exec_state)
                DATA_OUT_IDLE: begin
                    tx_done_deassert <= 1'b0;
                    if (data_all_processed) begin
                        mst_m_exec_state <= DATA_OUT_WRITE;
                    end
                end

                DATA_OUT_WRITE: begin
                    if (tx_done) begin
                        mst_m_exec_state <= DATA_OUT_IDLE;
                        tx_done_deassert <= 1'b1;
                    end
                end
            endcase
        end
    end

    assign axis_tvalid = ((mst_m_exec_state == DATA_OUT_WRITE) && (read_ptr < NUMBER_OF_OUTPUT_WORDS));
    assign axis_tlast = (read_ptr == NUMBER_OF_OUTPUT_WORDS-1);
    reg axis_tvalid_delay;
    assign M_AXIS_TVALID = axis_tvalid_delay;
    reg axis_tlast_delay;
    assign M_AXIS_TLAST	= axis_tlast_delay;

    // Delay the axis_tvalid and axis_tlast signal by one clock cycle
	// to match the latency of M_AXIS_TDATA

    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            axis_tvalid_delay <= 1'b0;
            axis_tlast_delay <= 1'b0;
        end else begin
            axis_tvalid_delay <= axis_tvalid;
            axis_tlast_delay <= axis_tlast;
        end
    end

    wire tx_en;
    reg tx_done_deassert;

    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            read_ptr <= 8'd0;
            tx_done <= 1'b0;
        end else begin
            if (read_ptr <= NUMBER_OF_INPUT_WORDS - 1) begin
                if (tx_en) begin
                    read_ptr <= read_ptr + 1;
                    tx_done <= 1'b0;
                end
            end else if (read_ptr == NUMBER_OF_INPUT_WORDS) begin
                tx_done <= 1'b1;
                read_ptr <= 8'd0;
            end

            if (tx_done_deassert) begin
                tx_done <= 1'b0;
            end
        end
    end

    assign tx_en = M_AXIS_TREADY && axis_tvalid;
    reg [31:0] stream_data_out;
    assign M_AXIS_TDATA = stream_data_out;
    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            stream_data_out <= 32'd0;
        end else begin
            if (tx_en) begin
                stream_data_out <= data_out_reg[read_ptr[2:0]];
            end
        end
    end
    
    // data process loop
    reg [7:0] process_ptr;
    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            data_all_processed <= 1'b0;
            process_ptr <= 8'd0;
        end else begin
            if (data_all_received) begin
                if (process_ptr == NUMBER_OF_INPUT_WORDS) begin
                    data_all_processed <= 1'b1;
                end else begin
                    // process data here
                    data_out_reg[process_ptr[2:0]] <= ~data_in_reg[process_ptr[2:0]];
                    process_ptr <= process_ptr + 1;
                end
            end else begin
                data_all_processed <= 1'b0; // make it as a pulse, two pulse actually because need to wait anotehr fsm to report
                process_ptr <= 8'd0;
            end
        end
    end

endmodule