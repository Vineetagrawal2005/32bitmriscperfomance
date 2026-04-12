// =============================================================================
//  Shifter1.v  —  Left shift by 2 (branch offset: sign_imm << 2)
//
//  No functional changes — original was already optimal.
// =============================================================================

module Shifter1(
    input  wire [31:0] sign_Imm,
    output wire [31:0] shifted_Sign_Imm
);

    assign shifted_Sign_Imm = {sign_Imm[29:0], 2'b00};

endmodule
