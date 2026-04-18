
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
