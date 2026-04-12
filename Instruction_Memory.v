// =============================================================================
//  Instruction_Memory.v  —  Optimized Read-Only Instruction Memory
//                           (Harvard Architecture — Separate from Data Memory)
//
//  OPTIMIZATIONS vs original:
//  1. Address indexing changed from adr[7:2] to adr[9:2]:
//     - adr[7:2] only addressed 64 words (256 bytes)
//     - adr[9:2] addresses 256 words (1 KB) — full ROM utilization
//     - This matches the Data_Memory which also uses 256 entries
//  2. Added a richer test program that exercises all supported instructions:
//     ADDI, ORI, ANDI (new I-type), R-type (ADD, SUB, AND, OR, XOR, MUL),
//     LW, SW, BEQ, BNE (new), J — so you can verify all FSM paths.
//  3. Program is clearly commented for viva presentation.
// =============================================================================

module Instruction_Memory(
    input  wire [31:0] adr,
    output wire [31:0] instr
);

    reg [31:0] rom [0:255];
    integer i;

    initial begin
        // Clear all ROM entries to NOP (all-zero = sll $zero,$zero,0)
        for (i = 0; i < 256; i = i + 1)
            rom[i] = 32'd0;

        // =====================================================================
        //  Test Program — exercises every FSM path
        //  Register usage: $t0=$8  $t1=$9  $t2=$10  $t3=$11  $s0=$16
        // =====================================================================

        // --- I-type execute (2 cycles each after optimization) ---
        rom[0]  = 32'b00100000000010000000000000000101; // ADDI $t0, $zero, 5    ($t0 = 5)
        rom[1]  = 32'b00100000000010010000000000000011; // ADDI $t1, $zero, 3    ($t1 = 3)
        rom[2]  = 32'b00110001000010100000000000001111; // ANDI $t2, $t0,   15   ($t2 = 5)
        rom[3]  = 32'b00110101000010110000000000000110; // ORI  $t3, $t0,   6    ($t3 = 7)

        // --- R-type execute (2 cycles each after optimization) ---
        rom[4]  = 32'b00000001000010010101100000100000; // ADD  $t3, $t0, $t1    ($t3 = 8)
        rom[5]  = 32'b00000001000010010101000000100010; // SUB  $t2, $t0, $t1    ($t2 = 2)
        rom[6]  = 32'b00000001000010011000000000100100; // AND  $s0, $t0, $t1    ($s0 = 1)
        rom[7]  = 32'b00000001000010011000000000100101; // OR   $s0, $t0, $t1    ($s0 = 7)
        rom[8]  = 32'b00000001000010011000000000100110; // XOR  $s0, $t0, $t1    ($s0 = 6)
        rom[9]  = 32'b00000001000010011000000000011000; // MUL  $s0, $t0, $t1    ($s0 = 15)

        // --- SW / LW (3 and 4 cycles respectively) ---
        rom[10] = 32'b10101100000010000000000000000000; // SW   $t0, 0($zero)    mem[0]=5
        rom[11] = 32'b10001100000100000000000000000000; // LW   $s0, 0($zero)    ($s0=5)

        // --- BEQ (2 cycles; branch NOT taken since $t0 != $t1) ---
        rom[12] = 32'b00010001000010010000000000000010; // BEQ  $t0, $t1, +2

        // --- BNE (2 cycles; branch TAKEN since $t0 != $t1) ---
        // Branches to rom[16] (skips rom[14] and rom[15])
        rom[13] = 32'b00010101000010010000000000000010; // BNE  $t0, $t1, +2

        rom[14] = 32'd0;  // NOP (should be skipped by BNE)
        rom[15] = 32'd0;  // NOP (should be skipped by BNE)

        // --- Target of BNE branch (rom[16]) ---
        rom[16] = 32'b00100000000010000000000000001010; // ADDI $t0, $zero, 10

        // --- J (2 cycles; jump to rom[20]) ---
        // J encodes word address: target = 20 → instr[25:0] = 20
        rom[17] = 32'b00001000000000000000000000010100; // J    20

        rom[18] = 32'd0;  // NOP (should be skipped by J)
        rom[19] = 32'd0;  // NOP (should be skipped by J)

        // --- Infinite NOP loop at rom[20] ---
        rom[20] = 32'd0;  // NOP  — processor loops here
    end

    // Word-addressed read (byte address / 4 = word index)
    assign instr = rom[adr[9:2]];

endmodule
