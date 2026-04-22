`timescale 1ns / 1ps

module Control_Branch(
    input  wire sig_Branch,
    input  wire sig_BranchNE,
    input  wire alu_Zero,
    input  wire sig_PCWrite,

    output wire pc_En
);

    wire beq_taken = sig_Branch   &  alu_Zero;
    wire bne_taken = sig_BranchNE & ~alu_Zero;

    assign pc_En = beq_taken | bne_taken | sig_PCWrite;

endmodule
