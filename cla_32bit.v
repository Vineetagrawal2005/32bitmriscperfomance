// =============================================================================
//  cla_32bit_improved.v  -  Optimized 32-bit CLA with ADD/SUB + Overflow
// =============================================================================

module cla_32bit(
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire        cin,     // carry in (used for ADD/SUB)
    input  wire        sub,     // 0 = ADD, 1 = SUB

    output wire [31:0] sum,
    output wire        cout,
    output wire        overflow
);

    // -------------------------------------------------------------
    // Modify B for subtraction (Two's complement)
    // -------------------------------------------------------------
    wire [31:0] b_mod;
    assign b_mod = sub ? ~b : b;

    wire carry_in;
    assign carry_in = sub ? 1'b1 : cin;

    // -------------------------------------------------------------
    // Bit-level generate and propagate
    // -------------------------------------------------------------
    wire [31:0] g = a & b_mod;
    wire [31:0] p = a ^ b_mod;

    // -------------------------------------------------------------
    // Group generate/propagate (8 groups of 4 bits)
    // -------------------------------------------------------------
    wire [7:0] GG, GP;

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : GROUP
            localparam B = i * 4;

            assign GG[i] = g[B+3]
                         | (p[B+3] & g[B+2])
                         | (p[B+3] & p[B+2] & g[B+1])
                         | (p[B+3] & p[B+2] & p[B+1] & g[B]);

            assign GP[i] = p[B+3] & p[B+2] & p[B+1] & p[B];
        end
    endgenerate

    // -------------------------------------------------------------
    // Group carry computation (lookahead)
    // -------------------------------------------------------------
    wire [8:0] Cg;

    assign Cg[0] = carry_in;
    assign Cg[1] = GG[0] | (GP[0] & Cg[0]);
    assign Cg[2] = GG[1] | (GP[1] & GG[0]) | (GP[1] & GP[0] & Cg[0]);
    assign Cg[3] = GG[2] | (GP[2] & GG[1]) | (GP[2] & GP[1] & GG[0])
                            | (GP[2] & GP[1] & GP[0] & Cg[0]);
    assign Cg[4] = GG[3] | (GP[3] & GG[2]) | (GP[3] & GP[2] & GG[1])
                            | (GP[3] & GP[2] & GP[1] & GG[0])
                            | (GP[3] & GP[2] & GP[1] & GP[0] & Cg[0]);
    assign Cg[5] = GG[4] | (GP[4] & GG[3]) | (GP[4] & GP[3] & GG[2])
                            | (GP[4] & GP[3] & GP[2] & GG[1])
                            | (GP[4] & GP[3] & GP[2] & GP[1] & GG[0])
                            | (GP[4] & GP[3] & GP[2] & GP[1] & GP[0] & Cg[0]);
    assign Cg[6] = GG[5] | (GP[5] & GG[4]) | (GP[5] & GP[4] & GG[3])
                            | (GP[5] & GP[4] & GP[3] & GG[2])
                            | (GP[5] & GP[4] & GP[3] & GP[2] & GG[1])
                            | (GP[5] & GP[4] & GP[3] & GP[2] & GP[1] & GG[0])
                            | (GP[5] & GP[4] & GP[3] & GP[2] & GP[1] & GP[0] & Cg[0]);
    assign Cg[7] = GG[6] | (GP[6] & GG[5]) | (GP[6] & GP[5] & GG[4])
                            | (GP[6] & GP[5] & GP[4] & GG[3])
                            | (GP[6] & GP[5] & GP[4] & GP[3] & GG[2])
                            | (GP[6] & GP[5] & GP[4] & GP[3] & GP[2] & GG[1])
                            | (GP[6] & GP[5] & GP[4] & GP[3] & GP[2] & GP[1] & GG[0])
                            | (GP[6] & GP[5] & GP[4] & GP[3] & GP[2] & GP[1] & GP[0] & Cg[0]);
    assign Cg[8] = GG[7] | (GP[7] & Cg[7]);

    // -------------------------------------------------------------
    // Bit-level carry inside each group
    // -------------------------------------------------------------
    wire [31:0] c;

    generate
        for (i = 0; i < 8; i = i + 1) begin : BIT
            localparam B = i * 4;
            wire cin_g = Cg[i];

            assign c[B]   = cin_g;
            assign c[B+1] = g[B]   | (p[B]   & cin_g);
            assign c[B+2] = g[B+1] | (p[B+1] & g[B]) | (p[B+1] & p[B] & cin_g);
            assign c[B+3] = g[B+2] | (p[B+2] & g[B+1]) | (p[B+2] & p[B+1] & g[B])
                                      | (p[B+2] & p[B+1] & p[B] & cin_g);
        end
    endgenerate

    // -------------------------------------------------------------
    // Final SUM
    // -------------------------------------------------------------
    assign sum = p ^ c;

    // -------------------------------------------------------------
    // Carry-out
    // -------------------------------------------------------------
    assign cout = Cg[8];

    // -------------------------------------------------------------
    // Overflow detection (signed)
    // -------------------------------------------------------------
    assign overflow = (a[31] & b_mod[31] & ~sum[31]) |
                      (~a[31] & ~b_mod[31] & sum[31]);

endmodule