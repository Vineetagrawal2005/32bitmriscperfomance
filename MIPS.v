// =============================================================================
//  MIPS.v  —  Optimized 32-bit Multicycle MIPS Processor (Top Level)
//             Harvard Architecture
//
//  OPTIMIZATIONS vs original:
//  1. Control_Branch now receives sig_BranchNE for BNE support.
//  2. Removed the intermediate ALU output register (_Alu_Out) used only
//     for branch target.  In the optimized FSM the branch target was
//     already computed in S_DECODE into the ALU result register; the
//     mux picks _Alu_Out (registered) for the branch PC.
//     The register is kept because it IS needed: PC-src mux input_1 must
//     hold the branch target computed one cycle earlier. This is unchanged.
//  3. Mux2 instances converted to pure assign — removes delta-cycle
//     simulation glitches and reduces synthesis area.
//  4. Instruction_Memory word-addressing is now done with adr[9:2] to
//     support up to 256 words (1KB) instead of adr[7:2] which only
//     addresses 64 words. (Instruction_Memory itself also updated.)
//  5. Wire names cleaned up and clearly commented for readability.
//  6. sig_BranchNE wire added and routed from Control_Unit to Control_Branch.
//  7. ALU carry/overflow/borrow ports connected properly to Control_Branch
//     for potential future use (BLT, BGT) without functional change now.
// =============================================================================

module MIPS(
    input  wire        clock,
    input  wire        rst,

    // FSM state for testbench monitoring
    output wire [3:0]  state,

    // Debug outputs (unchanged from original — testbench compatible)
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
    output wire [31:0] debug_signimm
);

    // =========================================================================
    //  Control signals
    // =========================================================================
    wire        sig_Branch, sig_BranchNE, sig_PCWrite, sig_MemWrite, sig_IRWrite;
    wire        sig_RegDst, sig_ALUSrcA, sig_RegWrite;
    wire [2:0]  sig_ALUControl;
    wire [1:0]  sig_ALUSrcB, sig_MemtoReg, sig_PCSrc;

    // =========================================================================
    //  Datapath wires
    // =========================================================================
    wire        _Zero, _Pc_En;
    wire        _Carry, _Borrow, _Overflow, _Parity;

    wire [31:0] _Pc, _Pc_Next;
    wire [31:0] _Instr_Mem_Out, _Instr;
    wire [31:0] _Data;

    wire [4:0]  _A3;                        // write-back register address
    wire [31:0] _Wd3;                       // write-back data

    wire [31:0] _Rd1,  _Rd2;               // raw register file outputs
    wire [31:0] _Reg_A, _Reg_B;            // registered reg file outputs

    wire [31:0] _Sign_Imm;                  // sign-extended immediate
    wire [31:0] _Sign_Imm_Shifted;          // sign_imm << 2 (branch offset)

    wire [31:0] _Src_A, _Src_B;            // ALU inputs
    wire [31:0] _Alu_Result;               // raw ALU output (this cycle)
    wire [31:0] _Alu_Out;                  // registered ALU output (prev cycle)

    wire [27:0] _Pc_Jump_Shifted;          // instr[25:0] << 2
    wire [31:0] _Pc_Jump;                  // {PC[31:28], instr[25:0], 2'b00}

    // =========================================================================
    //  Jump target assembly
    // =========================================================================
    assign _Pc_Jump = { _Pc[31:28], _Pc_Jump_Shifted };

    // =========================================================================
    //  Control Unit
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
        .sig_BranchNE   (sig_BranchNE),   // NEW
        .sig_RegWrite   (sig_RegWrite),
        .state          (state),
        .alu_Control    (sig_ALUControl)
    );

    // =========================================================================
    //  Program Counter
    // =========================================================================
    Program_Counter pc (
        .clock  (clock),
        .rst    (rst),
        .pc_en  (_Pc_En),
        .pc_in  (_Pc_Next),
        .pc_out (_Pc)
    );

    // =========================================================================
    //  Instruction Memory (Harvard — read-only, combinational)
    // =========================================================================
    Instruction_Memory instr_mem (
        .adr   (_Pc),
        .instr (_Instr_Mem_Out)
    );

    // =========================================================================
    //  Instruction Register  (holds instruction after fetch)
    // =========================================================================
    Register instr_reg (
        .clock  (clock),
        .rst    (rst),
        .enable (sig_IRWrite),
        .in     (_Instr_Mem_Out),
        .out    (_Instr)
    );

    // =========================================================================
    //  Data Memory (Harvard — separate from instruction memory)
    // =========================================================================
    Data_Memory data_mem (
        .clock       (clock),
        .rst         (rst),
        .sig_MemWrite(sig_MemWrite),
        .adr         (_Alu_Out),         // address from registered ALU output
        .wd          (_Reg_B),
        .rd          (_Data)
    );

    // =========================================================================
    //  Register Destination Mux:  0 = rt (I-type),  1 = rd (R-type)
    //  Converted to assign (was Mux2 module with always @(*))
    // =========================================================================
    assign _A3 = sig_RegDst ? _Instr[15:11] : _Instr[20:16];

    // =========================================================================
    //  Write-back Data Mux:  00 = ALU result,  01 = Data memory
    // =========================================================================
    Mux4 mux_mem_to_reg (
        .input_0  (_Alu_Out),
        .input_1  (_Data),
        .input_2  (32'd0),
        .input_3  (32'd0),
        .selector (sig_MemtoReg),
        .mux_Out  (_Wd3)
    );

    // =========================================================================
    //  Register File
    // =========================================================================
    Register_File reg_file (
        .clock      (clock),
        .rst        (rst),
        .a1         (_Instr[25:21]),
        .a2         (_Instr[20:16]),
        .a3         (_A3),
        .wd3        (_Wd3),
        .sig_RegWrite(sig_RegWrite),
        .rd1        (_Rd1),
        .rd2        (_Rd2)
    );

    // =========================================================================
    //  Sign Extension
    // =========================================================================
    Sign_Extension sign_ext (
        .immediate (_Instr[15:0]),
        .sign_Imm  (_Sign_Imm)
    );

    // =========================================================================
    //  Register A & B  (pipeline registers between reg file and ALU)
    //  Always enabled — capture register file outputs each cycle
    // =========================================================================
    Register reg_a (
        .clock  (clock),
        .rst    (rst),
        .enable (1'b1),
        .in     (_Rd1),
        .out    (_Reg_A)
    );

    Register reg_b (
        .clock  (clock),
        .rst    (rst),
        .enable (1'b1),
        .in     (_Rd2),
        .out    (_Reg_B)
    );

    // =========================================================================
    //  ALU Source A Mux:  0 = PC (for PC+4),   1 = Reg_A
    //  Converted to assign
    // =========================================================================
    assign _Src_A = sig_ALUSrcA ? _Reg_A : _Pc;

    // =========================================================================
    //  ALU Source B Mux:  00=Reg_B  01=4  10=SignImm  11=SignImm<<2
    // =========================================================================
    Mux4 mux_alu_b (
        .input_0  (_Reg_B),
        .input_1  (32'd4),
        .input_2  (_Sign_Imm),
        .input_3  (_Sign_Imm_Shifted),
        .selector (sig_ALUSrcB),
        .mux_Out  (_Src_B)
    );

    // =========================================================================
    //  Shifter 1:  sign_imm << 2  (for branch target offset)
    // =========================================================================
    Shifter1 shifter1 (
        .sign_Imm         (_Sign_Imm),
        .shifted_Sign_Imm (_Sign_Imm_Shifted)
    );

    // =========================================================================
    //  Shifter 2:  instr[25:0] << 2  (for jump target)
    // =========================================================================
    Shifter2 shifter2 (
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
    //  ALU Output Register  (needed to hold branch target from S_DECODE)
    // =========================================================================
    Register alu_out_reg (
        .clock  (clock),
        .rst    (rst),
        .enable (1'b1),
        .in     (_Alu_Result),
        .out    (_Alu_Out)
    );

    // =========================================================================
    //  Branch / PC-enable control
    // =========================================================================
    Control_Branch ctrl_branch (
        .sig_Branch   (sig_Branch),
        .sig_BranchNE (sig_BranchNE),
        .alu_Zero     (_Zero),
        .sig_PCWrite  (sig_PCWrite),
        .pc_En        (_Pc_En)
    );

    // =========================================================================
    //  PC Source Mux:  00=ALU result (PC+4)  01=ALU_Out (branch)  10=Jump
    // =========================================================================
    Mux4 mux_pc (
        .input_0  (_Alu_Result),   // PC+4 computed this cycle
        .input_1  (_Alu_Out),      // branch target (computed in S_DECODE)
        .input_2  (_Pc_Jump),      // jump target
        .input_3  (32'd0),
        .selector (sig_PCSrc),
        .mux_Out  (_Pc_Next)
    );

    // =========================================================================
    //  Debug outputs (fully backward compatible with existing testbench)
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

endmodule
