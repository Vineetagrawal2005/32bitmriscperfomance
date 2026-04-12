// =============================================================================
//  Sign_Extention.v  —  16-bit to 32-bit Sign Extension
//
//  No functional changes — original was already optimal.
//  Filename kept as Sign_Extention.v (matches original typo in project).
// =============================================================================

module Sign_Extension(
    input  wire [15:0] immediate,
    output wire [31:0] sign_Imm
);

    assign sign_Imm = {{16{immediate[15]}}, immediate};

endmodule
