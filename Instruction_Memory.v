`timescale 1ns / 1ps

module Instruction_Memory(
    input  wire [31:0] adr,
    output wire [31:0] instr
);

    reg [31:0] rom [0:255];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1)
            rom[i] = 32'd0;

       // ================= ARITHMETIC =================
    rom[0]  = 32'h2008_000A;   // ADDI $t0,10
    rom[1]  = 32'h2009_0005;   // ADDI $t1,5
    rom[2]  = 32'h0109_5020;   // ADD  $t2 = t0+t1 = 15
    rom[3]  = 32'h0109_5022;   // SUB  $t2 = t0-t1 = 5

    // ================= LOGIC =================
    rom[4]  = 32'h0109_5024;   // AND  $t2 = t0 & t1
    rom[5]  = 32'h0109_5025;   // OR   $t2 = t0 | t1
    rom[6]  = 32'h0109_5026;   // XOR  $t2 = t0 ^ t1

    // ================= SHIFT =================
    rom[7]  = 32'h00095080;   // SLL  $t2 = t1 << 2
    rom[8]  = 32'h00095082;   // SRL  $t2 = t1 >> 2

    // ================= IMMEDIATE =================
    rom[9]  = 32'h200A_0003;   // ADDI $t2,3
    rom[10] = 32'h314B_0001;   // ANDI $t3, t2,1
    rom[11] = 32'h354C_0002;   // ORI  $t4, t2,2

    // ================= MEMORY =================
    rom[12] = 32'hAC0A_0000;   // SW   $t2 → Mem[0]
    rom[13] = 32'h8C10_0000;   // LW   $s0 ← Mem[0]

    // ================= BRANCH =================
    rom[14] = 32'h1109_0001;   // BEQ  t0,t1 (NOT taken)
    rom[15] = 32'h1509_0001;   // BNE  t0,t1 (taken → skip next)

    rom[16] = 32'h200D_0007;   // SKIPPED if BNE works
    rom[17] = 32'h200D_0009;   // EXECUTED → t5 = 9

    // ================= JUMP =================
    rom[18] = 32'h0800_0012;   // J → 18 (loop)   // J    0x28  (self loop / halt)
    end

    assign instr = rom[adr[9:2]];

endmodule
