// =============================================================================
//  cla_32bit.v  —  True 4-bit Group Carry-Lookahead Adder (32-bit)
//
//  OPTIMIZATIONS vs original:
//  The original used a generate-loop with c[i+1] = g[i] | (p[i] & c[i]),
//  which is a RIPPLE-CARRY structure in disguise — each carry bit depends
//  on the previous one serially, giving O(n) critical path.
//
//  This version uses TRUE carry-lookahead:
//    - Divided into 8 groups of 4 bits each.
//    - Within each group, carry-out is computed in parallel using
//      group generate (G) and group propagate (P) equations.
//    - Group carries are then used to compute final carry into each group
//      in parallel (2-level lookahead).
//    - Critical path is now O(log n) rather than O(n).
//    - Fully synthesizable — maps cleanly to LUT chains or carry chains
//      on Xilinx/Intel FPGAs.
// =============================================================================

module cla_32bit(
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire        cin,
    output wire [31:0] sum,
    output wire        cout
);

    // -------------------------------------------------------------------------
    //  Bit-level generate and propagate
    // -------------------------------------------------------------------------
    wire [31:0] g = a & b;   // bit generate
    wire [31:0] p = a ^ b;   // bit propagate  (also used for sum = p ^ carry_in)

    // -------------------------------------------------------------------------
    //  8 groups of 4 bits: group generate (GG) and group propagate (GP)
    //
    //  For group i covering bits [4i+3 : 4i]:
    //    GG[i] = g3 | p3g2 | p3p2g1 | p3p2p1g0
    //    GP[i] = p3 & p2 & p1 & p0
    // -------------------------------------------------------------------------
    wire [7:0] GG, GP;  // group generate, group propagate

    genvar g_idx;
    generate
        for (g_idx = 0; g_idx < 8; g_idx = g_idx + 1) begin : GRP
            localparam B = g_idx * 4;   // base bit index for this group
            assign GG[g_idx] = g[B+3]
                              | (p[B+3] & g[B+2])
                              | (p[B+3] & p[B+2] & g[B+1])
                              | (p[B+3] & p[B+2] & p[B+1] & g[B+0]);
            assign GP[g_idx] = p[B+3] & p[B+2] & p[B+1] & p[B+0];
        end
    endgenerate

    // -------------------------------------------------------------------------
    //  Carry into each group — computed in parallel using group G/P
    //
    //  C_group[0] = cin
    //  C_group[i] = GG[i-1] | GP[i-1]*C_group[i-1]   (unrolled for speed)
    // -------------------------------------------------------------------------
    wire [8:0] C_group;
    assign C_group[0] = cin;
    assign C_group[1] = GG[0] | (GP[0] & C_group[0]);
    assign C_group[2] = GG[1] | (GP[1] & GG[0]) | (GP[1] & GP[0] & C_group[0]);
    assign C_group[3] = GG[2] | (GP[2] & GG[1]) | (GP[2] & GP[1] & GG[0])
                               | (GP[2] & GP[1] & GP[0] & C_group[0]);
    assign C_group[4] = GG[3] | (GP[3] & GG[2]) | (GP[3] & GP[2] & GG[1])
                               | (GP[3] & GP[2] & GP[1] & GG[0])
                               | (GP[3] & GP[2] & GP[1] & GP[0] & C_group[0]);
    assign C_group[5] = GG[4] | (GP[4] & GG[3]) | (GP[4] & GP[3] & GG[2])
                               | (GP[4] & GP[3] & GP[2] & GG[1])
                               | (GP[4] & GP[3] & GP[2] & GP[1] & GG[0])
                               | (GP[4] & GP[3] & GP[2] & GP[1] & GP[0] & C_group[0]);
    assign C_group[6] = GG[5] | (GP[5] & GG[4]) | (GP[5] & GP[4] & GG[3])
                               | (GP[5] & GP[4] & GP[3] & GG[2])
                               | (GP[5] & GP[4] & GP[3] & GP[2] & GG[1])
                               | (GP[5] & GP[4] & GP[3] & GP[2] & GP[1] & GG[0])
                               | (GP[5] & GP[4] & GP[3] & GP[2] & GP[1] & GP[0] & C_group[0]);
    assign C_group[7] = GG[6] | (GP[6] & GG[5]) | (GP[6] & GP[5] & GG[4])
                               | (GP[6] & GP[5] & GP[4] & GG[3])
                               | (GP[6] & GP[5] & GP[4] & GP[3] & GG[2])
                               | (GP[6] & GP[5] & GP[4] & GP[3] & GP[2] & GG[1])
                               | (GP[6] & GP[5] & GP[4] & GP[3] & GP[2] & GP[1] & GG[0])
                               | (GP[6] & GP[5] & GP[4] & GP[3] & GP[2] & GP[1] & GP[0] & C_group[0]);
    assign C_group[8] = GG[7] | (GP[7] & C_group[7]);   // final carry out

    // -------------------------------------------------------------------------
    //  Bit-level carry within each group (using true CLA equations)
    // -------------------------------------------------------------------------
    wire [31:0] c_bit;   // carry INTO each bit position

    genvar b_idx;
    generate
        for (g_idx = 0; g_idx < 8; g_idx = g_idx + 1) begin : BIT_CARRY
            localparam B = g_idx * 4;
            wire cg = C_group[g_idx];  // carry into this group
            assign c_bit[B+0] = cg;
            assign c_bit[B+1] = g[B+0] | (p[B+0] & cg);
            assign c_bit[B+2] = g[B+1] | (p[B+1] & g[B+0]) | (p[B+1] & p[B+0] & cg);
            assign c_bit[B+3] = g[B+2] | (p[B+2] & g[B+1]) | (p[B+2] & p[B+1] & g[B+0])
                                        | (p[B+2] & p[B+1] & p[B+0] & cg);
        end
    endgenerate

    // -------------------------------------------------------------------------
    //  Sum and carry-out
    // -------------------------------------------------------------------------
    assign sum  = p ^ c_bit;
    assign cout = C_group[8];

endmodule
