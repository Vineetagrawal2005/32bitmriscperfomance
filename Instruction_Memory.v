module Instruction_Memory(
    input  wire [31:0] adr,
    output wire [31:0] instr
);

    reg [31:0] rom [0:255];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1)
            rom[i] = 32'd0;

        // I-type
        rom[0]  = 32'h20080005; // ADDI $t0, $zero, 5
        rom[1]  = 32'h20090003; // ADDI $t1, $zero, 3
        rom[2]  = 32'h310A000F; // ANDI $t2, $t0, 15
        rom[3]  = 32'h350B0006; // ORI  $t3, $t0, 6

        // R-type
        rom[4]  = 32'h01095020; // ADD
        rom[5]  = 32'h01095022; // SUB
        rom[6]  = 32'h01098024; // AND
        rom[7]  = 32'h01098025; // OR
        rom[8]  = 32'h01098026; // XOR
        rom[9]  = 32'h01098018; // MUL

        // Memory
        rom[10] = 32'hAC080000; // SW
        rom[11] = 32'h8C100000; // LW

        // Branch (FIXED)
        rom[12] = 32'h11090001; // BEQ +1
        rom[13] = 32'h15090001; // BNE +1

        rom[14] = 32'd0;
        rom[15] = 32'd0;

        rom[16] = 32'h2008000A; // ADDI

        // Jump
        rom[17] = 32'h08000014; // J 20

        rom[18] = 32'd0;
        rom[19] = 32'd0;

        rom[20] = 32'd0;
    end

    assign instr = rom[adr[9:2]];

endmodule