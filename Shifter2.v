
module Shifter2(
    input  wire [25:0] sign_Imm,
    output wire [27:0] shifted_Sign_Imm
);

    assign shifted_Sign_Imm = {sign_Imm, 2'b00};

endmodule
