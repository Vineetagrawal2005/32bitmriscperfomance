module Sign_Extention(
    input  wire [15:0] immediate,
    input  wire [5:0]  opcode,      // NEW
    output wire [31:0] sign_Imm
);

    // ANDI = 001100
    // ORI  = 001101
    assign sign_Imm =
        (opcode == 6'b001100 || opcode == 6'b001101) ?
            {16'd0, immediate} :                 // ZERO EXTENSION
            {{16{immediate[15]}}, immediate};    // SIGN EXTENSION

endmodule