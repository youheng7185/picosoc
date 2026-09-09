module IOBUF (
    input  wire I,   // data in (drive to IO when T=0)
    input  wire T,   // tristate enable (1 = input mode, 0 = output mode)
    inout  wire IO,  // bidirectional pad
    output wire O    // data out (read from IO)
);
    assign IO = T ? 1'bz : I;
    assign O  = IO;
endmodule