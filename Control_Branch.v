// =============================================================================
//  Control_Branch.v  —  Optimized Branch Control Logic
//
//  OPTIMIZATIONS vs original:
//  1. Added BNE (Branch Not Equal) support via sig_BranchNE input.
//     BNE fires pc_En when alu_Zero is 0 (result was NOT zero).
//  2. Removed unused carry/overflow inputs — they added ports with no logic,
//     causing confusion in synthesis.  Can be re-added if BLTZ/BGTZ needed.
//  3. Pure combinational assign — no latency, no gates wasted.
// =============================================================================

module Control_Branch(
    input  wire sig_Branch,    // 1 when BEQ active
    input  wire sig_BranchNE,  // 1 when BNE active  (NEW)
    input  wire alu_Zero,      // 1 when ALU result == 0
    input  wire sig_PCWrite,   // unconditional PC write (Fetch / Jump states)

    output wire pc_En
);

    // BEQ taken  : branch & zero
    // BNE taken  : branchNE & ~zero
    wire beq_taken = sig_Branch   &  alu_Zero;
    wire bne_taken = sig_BranchNE & ~alu_Zero;

    assign pc_En = beq_taken | bne_taken | sig_PCWrite;

endmodule
