`timescale 1ns / 1ps
// =============================================================================
//  MIPS.v  -  32-bit Multicycle MIPS Processor (Harvard Architecture)
//
//  BUG FIXES APPLIED (see inline comments for detail):
//
//  FIX A (CRITICAL – was missing in original):
//    Removed the orphaned  always @(posedge clock)  block that wrote to
//    mem_data_reg only in state S_MREAD, and replaced it with the proper
//    registered-memory-data path ALREADY implemented in Data_Memory.v.
//    The old block declared mem_data_reg as a reg in MIPS.v and fed it to
//    the writeback mux, but Data_Memory.v already has its own internal
//    rd_reg that is clocked on MemRead.  Having two separate latches for
//    the same datum means LW always writes stale (previous) data because
//    the MIPS-level latch captured _Data one cycle AFTER Data_Memory.v's
//    rd_reg was updated.  Removing mem_data_reg and connecting the mux
//    directly to _Data (which is wired to data_mem.rd = data_mem.rd_reg)
//    fixes LW writeback.
//
//  FIX B (port-count):
//    The old testbench instantiated MIPS with only 7 ports; the module
//    declaration has 14.  All ports are kept; the testbench is fixed to
//    match (see MIPS_tb.v fix).
//
//  Everything else (FIX 1-4 described in comments below) was already
//  correctly applied in the version you uploaded.
// =============================================================================

module MIPS(
    input  wire        clock,
    input  wire        rst,

    output wire [3:0]  state,

    output wire [31:0] debug_pc,
    output wire [31:0] debug_instr,
    output wire [31:0] debug_alu,
    output wire [31:0] debug_regA,
    output wire [31:0] debug_regB,
    output wire [31:0] debug_srcA,
    output wire [31:0] debug_srcB,
    output wire [31:0] debug_alu_out,
    output wire [31:0] debug_mem_data,
    output wire [31:0] debug_wd3,
    output wire [31:0] debug_signimm,
    output wire        debug_MemWrite,
    output wire        debug_RegWrite
);

    // =========================================================================
    //  CONTROL SIGNALS
    // =========================================================================
    wire        sig_Branch, sig_BranchNE, sig_PCWrite, sig_MemWrite, sig_IRWrite;
    wire        sig_RegDst, sig_ALUSrcA, sig_RegWrite;
    wire [2:0]  sig_ALUControl;
    wire [1:0]  sig_ALUSrcB, sig_MemtoReg, sig_PCSrc;
    wire        sig_MemRead;

    // =========================================================================
    //  DATAPATH WIRES
    // =========================================================================
    wire        _Zero, _Pc_En;
    wire        _Carry, _Borrow, _Overflow, _Parity;

    wire [31:0] _Pc, _Pc_Next;
    wire [31:0] _Instr_Mem_Out, _Instr;
    wire [31:0] _Data;

    wire [4:0]  _A3;
    wire [31:0] _Wd3;

    wire [31:0] _Rd1, _Rd2;
    wire [31:0] _Reg_A, _Reg_B;

    wire [31:0] _Sign_Imm;
    wire [31:0] _Sign_Imm_Shifted;

    wire [31:0] _Src_A, _Src_B;
    wire [31:0] _Alu_Result;   // CURRENT cycle ALU output (combinational)
    wire [31:0] _Alu_Out;      // PREVIOUS cycle ALU output (registered)

    wire [27:0] _Pc_Jump_Shifted;
    wire [31:0] _Pc_Jump;

    // =========================================================================
    //  JUMP ADDRESS   { PC[31:28], instr[25:0] << 2 }
    // =========================================================================
    assign _Pc_Jump = { _Pc[31:28], _Pc_Jump_Shifted };

    // =========================================================================
    //  CONTROL UNIT  (Moore FSM)
    // =========================================================================
    Control_Unit control (
        .clock          (clock),
        .rst            (rst),
        .instr_Opcode   (_Instr[31:26]),
        .instr_Function (_Instr[5:0]),
        .sig_MemtoReg   (sig_MemtoReg),
        .sig_RegDst     (sig_RegDst),
        .sig_PCSrc      (sig_PCSrc),
        .sig_ALUSrcB    (sig_ALUSrcB),
        .sig_ALUSrcA    (sig_ALUSrcA),
        .sig_IRWrite    (sig_IRWrite),
        .sig_MemWrite   (sig_MemWrite),
        .sig_PCWrite    (sig_PCWrite),
        .sig_Branch     (sig_Branch),
        .sig_BranchNE   (sig_BranchNE),
        .sig_RegWrite   (sig_RegWrite),
        .sig_MemRead    (sig_MemRead),
        .state          (state),
        .alu_Control    (sig_ALUControl)
    );

    // =========================================================================
    //  PROGRAM COUNTER
    // =========================================================================
    Program_Counter pc (
        .clock  (clock),
        .rst    (rst),
        .pc_en  (_Pc_En),
        .pc_in  (_Pc_Next),
        .pc_out (_Pc)
    );

    // =========================================================================
    //  INSTRUCTION MEMORY  (Harvard ROM, word-addressed)
    // =========================================================================
    Instruction_Memory instr_mem (
        .adr   (_Pc),
        .instr (_Instr_Mem_Out)
    );

    // =========================================================================
    //  INSTRUCTION REGISTER  (enabled only in S_FETCH)
    // =========================================================================
    Register instr_reg (
        .clock  (clock),
        .rst    (rst),
        .enable (sig_IRWrite),
        .in     (_Instr_Mem_Out),
        .out    (_Instr)
    );

    // =========================================================================
    //  DATA MEMORY  (Harvard RAM)
    //  Address  = _Alu_Out  (registered address from S_MADR — FIX 4 preserved)
    //  rd       = _Data (wire → data_mem.rd_reg, already clocked inside DM)
    //
    //  FIX A: We NO LONGER add a second latch (mem_data_reg) here.
    //  data_mem.rd_reg is updated on MemRead in S_MREAD and its value is
    //  stable by S_MWBACK (one cycle later), so _Data is already correct
    //  when sig_RegWrite goes high in S_MWBACK.
    // =========================================================================
    Data_Memory data_mem (
        .clock    (clock),
        .rst      (rst),
        .MemWrite (sig_MemWrite),
        .MemRead  (sig_MemRead),
        .adr      (_Alu_Out),
        .wd       (_Reg_B),
        .rd       (_Data)
    );

    // =========================================================================
    //  REGISTER DESTINATION MUX
    //  sig_RegDst = 0 → rt [20:16]  (I-type)
    //  sig_RegDst = 1 → rd [15:11]  (R-type)
    // =========================================================================
    assign _A3 = sig_RegDst ? _Instr[15:11] : _Instr[20:16];

    // =========================================================================
    //  WRITE-BACK DATA MUX
    //  sig_MemtoReg = 00 → _Alu_Result  (R-type / I-type execute, FIX 1)
    //  sig_MemtoReg = 01 → _Data        (LW writeback — direct from DM output)
    // =========================================================================
    Mux_4_Bit mux_mem_to_reg (
        .input_0  (_Alu_Result),   // FIX 1: current-cycle result for R/I
        .input_1  (_Data),         // FIX A: use _Data directly, not a 2nd latch
        .input_2  (32'd0),
        .input_3  (32'd0),
        .selector (sig_MemtoReg),
        .mux_Out  (_Wd3)
    );

    // =========================================================================
    //  REGISTER FILE  (32 × 32)
    // =========================================================================
    Register_File reg_file (
        .clock    (clock),
        .rst      (rst),
        .a1       (_Instr[25:21]),
        .a2       (_Instr[20:16]),
        .a3       (_A3),
        .wd3      (_Wd3),
        .RegWrite (sig_RegWrite),
        .rd1      (_Rd1),
        .rd2      (_Rd2)
    );

    // =========================================================================
    //  SIGN EXTENSION  16-bit → 32-bit
    // =========================================================================
    Sign_Extention sign_ext (
    .immediate (_Instr[15:0]),
    .opcode    (_Instr[31:26]),   // ADD THIS
    .sign_Imm  (_Sign_Imm)
);

    // =========================================================================
    //  REGISTER A  (pipeline register — always enabled, FIX 2 preserved)
    // =========================================================================
    Register reg_a (
        .clock  (clock),
        .rst    (rst),
        .enable (1'b1),
        .in     (_Rd1),
        .out    (_Reg_A)
    );

    // =========================================================================
    //  REGISTER B  (pipeline register — always enabled, FIX 2 preserved)
    // =========================================================================
    Register reg_b (
        .clock  (clock),
        .rst    (rst),
        .enable (1'b1),
        .in     (_Rd2),
        .out    (_Reg_B)
    );

    // =========================================================================
    //  ALU SOURCE A MUX
    //  0 → _Pc   (S_FETCH)
    //  1 → _Reg_A (all execution states)
    // =========================================================================
    assign _Src_A = sig_ALUSrcA ? _Reg_A : _Pc;

    // =========================================================================
    //  ALU SOURCE B MUX  (4-to-1)
    //  00 → _Reg_B
    //  01 → 32'd4
    //  10 → _Sign_Imm
    //  11 → _Sign_Imm_Shifted
    // =========================================================================
    Mux_4_Bit mux_alu_b (
        .input_0  (_Reg_B),
        .input_1  (32'd4),
        .input_2  (_Sign_Imm),
        .input_3  (_Sign_Imm_Shifted),
        .selector (sig_ALUSrcB),
        .mux_Out  (_Src_B)
    );

    // =========================================================================
    //  SHIFTER 1  — branch offset: sign_imm << 2
    // =========================================================================
    Shifter1 sh1 (
        .sign_Imm         (_Sign_Imm),
        .shifted_Sign_Imm (_Sign_Imm_Shifted)
    );

    // =========================================================================
    //  SHIFTER 2  — jump target: instr[25:0] << 2
    // =========================================================================
    Shifter2 sh2 (
        .sign_Imm         (_Instr[25:0]),
        .shifted_Sign_Imm (_Pc_Jump_Shifted)
    );

    // =========================================================================
    //  ALU
    // =========================================================================
    Alu alu (
        .alu_Control (sig_ALUControl),
        .src_A       (_Src_A),
        .src_B       (_Src_B),
        .alu_Result  (_Alu_Result),
        .alu_Zero    (_Zero),
        .carry       (_Carry),
        .borrow      (_Borrow),
        .overflow    (_Overflow),
        .parity      (_Parity)
    );

    // =========================================================================
    //  ALU OUTPUT REGISTER  (always enabled, FIX 3 preserved)
    // =========================================================================
    Register alu_reg (
        .clock  (clock),
        .rst    (rst),
        .enable (1'b1),
        .in     (_Alu_Result),
        .out    (_Alu_Out)
    );

    // =========================================================================
    //  BRANCH CONTROL
    // =========================================================================
    Control_Branch branch (
        .sig_Branch   (sig_Branch),
        .sig_BranchNE (sig_BranchNE),
        .alu_Zero     (_Zero),
        .sig_PCWrite  (sig_PCWrite),
        .pc_En        (_Pc_En)
    );

    // =========================================================================
    //  PC SOURCE MUX  (4-to-1)
    //  00 → _Alu_Result  (PC+4, S_FETCH)
    //  01 → _Alu_Out     (branch target from S_DECODE)
    //  10 → _Pc_Jump     (jump)
    // =========================================================================
    Mux_4_Bit mux_pc (
        .input_0  (_Alu_Result),
        .input_1  (_Alu_Out),
        .input_2  (_Pc_Jump),
        .input_3  (32'd0),
        .selector (sig_PCSrc),
        .mux_Out  (_Pc_Next)
    );

    // =========================================================================
    //  DEBUG OUTPUTS
    // =========================================================================
    assign debug_pc       = _Pc;
    assign debug_instr    = _Instr;
    assign debug_alu      = _Alu_Result;
    assign debug_regA     = _Reg_A;
    assign debug_regB     = _Reg_B;
    assign debug_srcA     = _Src_A;
    assign debug_srcB     = _Src_B;
    assign debug_alu_out  = _Alu_Out;
    assign debug_mem_data = _Data;
    assign debug_wd3      = _Wd3;
    assign debug_signimm  = _Sign_Imm;
    assign debug_MemWrite = sig_MemWrite;
    assign debug_RegWrite = sig_RegWrite;

endmodule
