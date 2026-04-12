// =============================================================================
//  Mux_2_bit.v  —  2-to-1 32-bit Multiplexer
//
//  OPTIMIZATIONS vs original:
//  1. Replaced always @(*) / reg output with a single assign statement.
//     The original `always` block and `reg` output is functionally
//     equivalent but introduces an extra simulation delta cycle for
//     updates.  Pure `assign` with a ternary operator is:
//       - Synthesized identically (1 LUT-based mux)
//       - Faster in simulation (no scheduling overhead)
//       - Cleaner and more conventional for combinational muxes
// =============================================================================

module Mux2(
    input  wire [31:0] input_0,
    input  wire [31:0] input_1,
    input  wire        selector,
    output wire [31:0] mux_Out
);

    assign mux_Out = selector ? input_1 : input_0;

endmodule
