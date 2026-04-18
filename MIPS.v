`timescale 1ns / 1ps

module MIPS(
    input  wire        clock,
    input  wire        rst,

    output wire [3:0]  state,

    // Debug
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
    output wire debug_MemWrite,
    output wire debug_RegWrite
);

    // =========================
    // CONTROL SIGNALS
    // =========================
    wire sig_Branch, sig_BranchNE, sig_PCWrite, sig_MemWrite, sig_IRWrite;
    wire sig_RegDst, sig_ALUSrcA, sig_RegWrite;
    wire [2:0] sig_ALUControl;
    wire [1:0] sig_ALUSrcB, sig_MemtoReg, sig_PCSrc;

    // =========================
    // DATAPATH
    // =========================
    wire _Zero, _Pc_En;
    wire _Carry, _Borrow, _Overflow, _Parity;

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
    wire [31:0] _Alu_Result;
    wire [31:0] _Alu_Out;

    wire [27:0] _Pc_Jump_Shifted;
    wire [31:0] _Pc_Jump;

    // =========================
    // JUMP ADDRESS
    // =========================
    assign _Pc_Jump = { _Pc[31:28], _Pc_Jump_Shifted };

    // =========================
    // CONTROL UNIT
    // =========================
    Control_Unit control (
        .clock(clock),
        .rst(rst),
        .instr_Opcode(_Instr[31:26]),
        .instr_Function(_Instr[5:0]),
        .sig_MemtoReg(sig_MemtoReg),
        .sig_RegDst(sig_RegDst),
        .sig_PCSrc(sig_PCSrc),
        .sig_ALUSrcB(sig_ALUSrcB),
        .sig_ALUSrcA(sig_ALUSrcA),
        .sig_IRWrite(sig_IRWrite),
        .sig_MemWrite(sig_MemWrite),
        .sig_PCWrite(sig_PCWrite),
        .sig_Branch(sig_Branch),
        .sig_BranchNE(sig_BranchNE),
        .sig_RegWrite(sig_RegWrite),
        .state(state),
        .alu_Control(sig_ALUControl)
    );

    // =========================
    // PROGRAM COUNTER
    // =========================
    Program_Counter pc (
        .clock(clock),
        .rst(rst),
        .pc_en(_Pc_En),
        .pc_in(_Pc_Next),
        .pc_out(_Pc)
    );

    // =========================
    // INSTRUCTION MEMORY
    // =========================
    Instruction_Memory instr_mem (
        .adr(_Pc),
        .instr(_Instr_Mem_Out)
    );

    // =========================
    // INSTRUCTION REGISTER
    // =========================
    Register instr_reg (
        .clock(clock),
        .rst(rst),
        .enable(sig_IRWrite),
        .in(_Instr_Mem_Out),
        .out(_Instr)
    );

    // =========================
    // DATA MEMORY
    // =========================
    Data_Memory data_mem (
    .clock(clock),
    .rst(rst),
    .MemWrite(sig_MemWrite),
    .MemRead(1'b1),   // ✅ FIXED
    .adr(_Alu_Result),
    .wd(_Reg_B),
    .rd(_Data)
);

    // =========================
    // REGISTER DESTINATION
    // =========================
    assign _A3 = sig_RegDst ? _Instr[15:11] : _Instr[20:16];

    // =========================
    // WRITE BACK
    // =========================
   Mux4 mux_mem_to_reg (
    .input_0(_Alu_Result),   // ✅ FIXED
    .input_1(_Data),
    .input_2(32'd0),
    .input_3(32'd0),
    .selector(sig_MemtoReg),
    .mux_Out(_Wd3)
);

    // =========================
    // REGISTER FILE
    // =========================
    Register_File reg_file (
    .clock(clock),
    .rst(rst),
    .a1(_Instr[25:21]),
    .a2(_Instr[20:16]),
    .a3(_A3),
    .wd3(_Wd3),
    .RegWrite(sig_RegWrite),   // ✅ FIXED
    .rd1(_Rd1),
    .rd2(_Rd2)
);

    // =========================
    // SIGN EXTENSION
    // =========================
    Sign_Extension sign_ext (
        .immediate(_Instr[15:0]),
        .sign_Imm(_Sign_Imm)
    );

    // =========================
    // REG A / REG B
    // =========================
   Register reg_a (
    .clock(clock),
    .rst(rst),
    .enable(state == 1),   // ✅ FIX
    .in(_Rd1),
    .out(_Reg_A)
);

Register reg_b (
    .clock(clock),
    .rst(rst),
    .enable(state == 1),   // ✅ FIX
    .in(_Rd2),
    .out(_Reg_B)
);

    // =========================
    // ALU INPUT
    // =========================
    assign _Src_A = sig_ALUSrcA ? _Reg_A : _Pc;

    Mux4 mux_alu_b (
        .input_0(_Reg_B),
        .input_1(32'd4),
        .input_2(_Sign_Imm),
        .input_3(_Sign_Imm_Shifted),
        .selector(sig_ALUSrcB),
        .mux_Out(_Src_B)
    );

    // =========================
    // SHIFT
    // =========================
    Shifter1 sh1 (.sign_Imm(_Sign_Imm), .shifted_Sign_Imm(_Sign_Imm_Shifted));
    Shifter2 sh2 (.sign_Imm(_Instr[25:0]), .shifted_Sign_Imm(_Pc_Jump_Shifted));

    // =========================
    // ALU
    // =========================
    Alu alu (
        .alu_Control(sig_ALUControl),
        .src_A(_Src_A),
        .src_B(_Src_B),
        .alu_Result(_Alu_Result),
        .alu_Zero(_Zero),
        .carry(_Carry),
        .borrow(_Borrow),
        .overflow(_Overflow),
        .parity(_Parity)
    );

    // =========================
    // ALU REGISTER
    // =========================
    Register alu_reg (
        .clock(clock),
        .rst(rst),
        .enable(state == 1),
        .in(_Alu_Result),
        .out(_Alu_Out)
    );

    // =========================
    // BRANCH CONTROL
    // =========================
    Control_Branch branch (
        .sig_Branch(sig_Branch),
        .sig_BranchNE(sig_BranchNE),
        .alu_Zero(_Zero),
        .sig_PCWrite(sig_PCWrite),
        .pc_En(_Pc_En)
    );

    // =========================
    // PC MUX
    // =========================
    Mux4 mux_pc (
        .input_0(_Alu_Result),
        .input_1(_Alu_Out),
        .input_2(_Pc_Jump),
        .input_3(32'd0),
        .selector(sig_PCSrc),
        .mux_Out(_Pc_Next)
    );

    // =========================
    // DEBUG
    // =========================
    assign debug_pc = _Pc;
    assign debug_instr = _Instr;
    assign debug_alu = _Alu_Result;
    assign debug_regA = _Reg_A;
    assign debug_regB = _Reg_B;
    assign debug_srcA = _Src_A;
    assign debug_srcB = _Src_B;
    assign debug_alu_out = _Alu_Out;
    assign debug_mem_data = _Data;
    assign debug_wd3 = _Wd3;
    assign debug_signimm = _Sign_Imm;
    assign debug_MemWrite = sig_MemWrite;
    assign debug_RegWrite = sig_RegWrite;

endmodule