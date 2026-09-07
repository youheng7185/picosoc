module ODDR #(
    parameter DDR_CLK_EDGE = "SAME_EDGE",
    parameter INIT         = 1'b0,
    parameter SRTYPE       = "SYNC"
)(
    output reg Q,
    input  wire C,
    input  wire CE,
    input  wire D1,
    input  wire D2,
    input  wire R,
    input  wire S
);

initial Q = INIT;

// Rising edge: output D1
always @(posedge C) begin
    if (S)
        Q <= 1'b1;
    else if (R)
        Q <= 1'b0;
    else if (CE)
        Q <= D1;
end

// Falling edge: output D2
always @(negedge C) begin
    if (S)
        Q <= 1'b1;
    else if (R)
        Q <= 1'b0;
    else if (CE)
        Q <= D2;
end

endmodule