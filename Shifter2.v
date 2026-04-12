// =============================================================================
//  Shifter2.v  —  Left shift by 2 (jump target: instr[25:0] << 2 → 28-bit)
//
//  No functional changes — original was already optimal.
// =============================================================================

module Shifter2(
    input  wire [25:0] sign_Imm,
    output wire [27:0] shifted_Sign_Imm
);

    assign shifted_Sign_Imm = {sign_Imm, 2'b00};

endmodule
