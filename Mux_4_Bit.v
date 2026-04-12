// =============================================================================
//  Mux_4_Bit.v  —  4-to-1 32-bit Multiplexer
//
//  No functional changes — original was already optimal (pure assign).
//  Minor: port declarations use wire explicitly for clarity.
// =============================================================================

module Mux4(
    input  wire [31:0] input_0,
    input  wire [31:0] input_1,
    input  wire [31:0] input_2,
    input  wire [31:0] input_3,
    input  wire [1:0]  selector,
    output wire [31:0] mux_Out
);

    assign mux_Out =
        (selector == 2'b00) ? input_0 :
        (selector == 2'b01) ? input_1 :
        (selector == 2'b10) ? input_2 :
                              input_3;

endmodule
