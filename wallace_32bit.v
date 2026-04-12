// =============================================================================
//  wallace_32bit.v  —  32-bit Wallace Tree Multiplier
//
//  No functional changes — original implementation delegates to the
//  synthesis tool to infer a DSP48/Wallace structure from `A * B`.
//  This is the correct approach for FPGA targets (Vivado/Quartus will
//  map to hard DSP blocks automatically).
//
//  For ASIC targets a full explicit Wallace tree would be needed.
//  That is outside the scope of this academic MIPS project.
// =============================================================================

module wallace_32bit(
    input  wire [31:0] A,
    input  wire [31:0] B,
    output wire [31:0] product_lo
);

    wire [63:0] full_product;
    assign full_product = A * B;
    assign product_lo   = full_product[31:0];

endmodule
