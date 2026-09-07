// module fifo (
//     input wire clk_i,
//     input wire rst_n,
//     input wire wr_en,
//     input wire rd_en,
//     input wire [31:0] din,
//     output reg [31:0] dout,
//     output wire full_o,
//     output wire empty_o
// );

//     // depth set 64, so total 256 bytes fifo

//     reg [5:0] wptr;
//     reg [5:0] rptr;

//     reg [31:0] fifo_mem [0:63];

//     always @(posedge clk_i or negedge rst_n) begin
//         if (!rst_n) begin
//             wptr <= 0;
//         end else begin
//             if (wr_en && !full_o) begin
//                 fifo_mem[wptr] <= din;
//                 wptr <= wptr + 1;
//             end
//         end
//     end

//     always @(posedge clk_i or negedge rst_n) begin
//         if (!rst_n) begin
//             rptr <= 0;
//         end else begin
//             if (rd_en & !empty_o) begin
//                 dout <= fifo_mem[rptr];
//                 rptr <= rptr + 1;
//             end
//         end
//     end

//     assign full_o = (wptr + 1) == rptr;
//     assign empty_o = wptr == rptr;

// endmodule

module fifo (
    input  wire        clk_i,
    input  wire        rst_n,
    input  wire        wr_en,
    input  wire        rd_en,
    input  wire [31:0] din,
    output wire [31:0] dout,       // wire, not reg
    output wire        full_o,
    output wire        empty_o
);

    reg [5:0] wptr;
    reg [5:0] rptr;

    // Simple dual-port style — write port and read port separate
    (* ram_style = "block" *)          // force BRAM inference
    reg [31:0] fifo_mem [0:63];

    // Write port — synchronous only
    always @(posedge clk_i) begin
        if (wr_en && !full_o) begin
            fifo_mem[wptr] <= din;
        end
    end

    // Read port — synchronous read (BRAM requires this)
    // dout updates the cycle AFTER rd_en, same as before so no change to your FSM
    reg [31:0] dout_r;
    always @(posedge clk_i) begin
        if (rd_en && !empty_o) begin
            dout_r <= fifo_mem[rptr];
        end else if (rd_en) begin
            dout_r <= 32'h88888888;
        end
    end
    assign dout = dout_r;

    // Pointers — synchronous reset
    always @(posedge clk_i) begin
        if (!rst_n) begin
            wptr <= 6'd0;
        end else begin
            if (wr_en && !full_o) begin
                wptr <= wptr + 1;
            end
        end
    end

    always @(posedge clk_i) begin
        if (!rst_n) begin
            rptr <= 6'd0;
        end else begin
            if (rd_en && !empty_o) begin
                rptr <= rptr + 1;
            end
        end
    end

    assign full_o  = ((wptr + 1) & 6'h3F) == rptr;
    assign empty_o = wptr == rptr;

endmodule