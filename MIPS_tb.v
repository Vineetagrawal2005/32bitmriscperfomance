`timescale 1ns / 1ps

module MIPS_tb;

reg clock, rst;

initial clock = 0;
always #5 clock = ~clock;

// ================= DEBUG SIGNALS =================
wire [3:0]  state;
wire [31:0] debug_pc, debug_instr, debug_alu;
wire [31:0] debug_regA, debug_regB, debug_srcA, debug_srcB;
wire [31:0] debug_alu_out, debug_mem_data, debug_wd3, debug_signimm;
wire        debug_MemWrite, debug_RegWrite;

// ================= DUT =================
MIPS uut (
    .clock          (clock),
    .rst            (rst),
    .state          (state),
    .debug_pc       (debug_pc),
    .debug_instr    (debug_instr),
    .debug_alu      (debug_alu),
    .debug_regA     (debug_regA),
    .debug_regB     (debug_regB),
    .debug_srcA     (debug_srcA),
    .debug_srcB     (debug_srcB),
    .debug_alu_out  (debug_alu_out),
    .debug_mem_data (debug_mem_data),
    .debug_wd3      (debug_wd3),
    .debug_signimm  (debug_signimm),
    .debug_MemWrite (debug_MemWrite),
    .debug_RegWrite (debug_RegWrite)
);

// State string for pretty printing
reg [47:0] state_name;
always @(*) begin
    case (state)
        4'd0:  state_name = "FETCH ";
        4'd1:  state_name = "DECODE";
        4'd2:  state_name = "MADR  ";
        4'd3:  state_name = "MREAD ";
        4'd4:  state_name = "MWBACK";
        4'd5:  state_name = "MWRITE";
        4'd6:  state_name = "REXEC ";
        4'd8:  state_name = "BEXEC ";
        4'd9:  state_name = "IEXEC ";
        4'd11: state_name = "JUMP  ";
        default: state_name = "UNKNOWN";
    endcase
end

// Instruction string for pretty printing
reg [8*15:1] instr_string;
always @(*) begin
    case (debug_instr)
        32'h2008_000A: instr_string = "ADDI t0, 10    ";
        32'h2009_0005: instr_string = "ADDI t1, 5     ";
        32'h0109_5020: instr_string = "ADD  t2, t0, t1";
        32'hAC0A_0000: instr_string = "SW   t2, 0(z)  ";
        32'h8C10_0000: instr_string = "LW   s0, 0(z)  ";
        32'h200B_0003: instr_string = "ADDI t3, 3     ";
        32'h016A_5822: instr_string = "SUB  t3, t3, t2";
        32'h200C_0001: instr_string = "ADDI t4, 1     ";
        32'h1180_0001: instr_string = "BEQ  t4, z, 1  ";
        32'h200D_0007: instr_string = "ADDI t5, 7     ";
        32'hAC0D_0004: instr_string = "SW   t5, 4(z)  ";
        32'h8C11_0004: instr_string = "LW   s1, 4(z)  ";
        32'h0800_000C: instr_string = "J    loop      ";
        32'h0000_0000: instr_string = "NOP            ";
        default:       instr_string = "UNKNOWN        ";
    endcase
end

// ================= LOAD PROGRAM =================
integer i;
initial begin
    // Clear ROM
    for (i = 0; i < 256; i = i + 1)
        uut.instr_mem.rom[i] = 32'd0;

    // ================= PROGRAM =================
    uut.instr_mem.rom[0]  = 32'h2008_000A;   // ADDI t0, zero, 10
    uut.instr_mem.rom[1]  = 32'h2009_0005;   // ADDI t1, zero, 5
    uut.instr_mem.rom[2]  = 32'h0109_5020;   // ADD  t2, t0, t1   -> 15
    uut.instr_mem.rom[3]  = 32'hAC0A_0000;   // SW   t2, 0(zero)  -> mem[0] = 15
    uut.instr_mem.rom[4]  = 32'h8C10_0000;   // LW   s0, 0(zero)  -> s0 = 15

    uut.instr_mem.rom[5]  = 32'h200B_0003;   // ADDI t3, zero, 3
    uut.instr_mem.rom[6]  = 32'h016A_5822;   // SUB  t3, t3, t2   -> 3 - 15 = -12

    uut.instr_mem.rom[7]  = 32'h200C_0001;   // ADDI t4, zero, 1
    uut.instr_mem.rom[8]  = 32'h1180_0001;   // BEQ  t4, zero, 1  (not taken)

    uut.instr_mem.rom[9]  = 32'h200D_0007;   // ADDI t5, zero, 7
    
    uut.instr_mem.rom[10] = 32'hAC0D_0004;   // SW   t5, 4(zero)  -> mem[4] = 7
    uut.instr_mem.rom[11] = 32'h8C11_0004;   // LW   s1, 4(zero)  -> s1 = 7

    uut.instr_mem.rom[12] = 32'h0800_000C;   // J    12 (infinite loop)
end

// ================= RESET =================
initial begin
    rst = 1;
    #20 rst = 0;
end

// ================= MONITOR =================
initial begin
    $display("Time   State   PC        Instr       Mnemonic         ALU          WD3       MemW RegW");
    $monitor("%4t  %s  %h  %h  %s  %11d  %11d   %b    %b",
        $time, state_name, debug_pc, debug_instr, instr_string,
        $signed(debug_alu), $signed(debug_wd3),
        debug_MemWrite, debug_RegWrite);
end

// ================= FINAL CHECK =================
reg all_passed;
initial begin
    #800;
    all_passed = 1;

    $display("\n=======================================================");
    $display("                 FINAL VERIFICATION LOG                  ");
    $display("=======================================================");

    $display("\n--- Register Verification ---");
    
    // Check ADDI
    if ($signed(uut.reg_file.reg_File[8]) == 10) $display("✅ [PASS] ADDI t0, 10  -> t0 = 10");
    else begin $display("❌ [FAIL] ADDI t0, 10  -> t0 = %0d (Expected 10)", $signed(uut.reg_file.reg_File[8])); all_passed = 0; end

    if ($signed(uut.reg_file.reg_File[9]) == 5) $display("✅ [PASS] ADDI t1, 5   -> t1 = 5");
    else begin $display("❌ [FAIL] ADDI t1, 5   -> t1 = %0d (Expected 5)", $signed(uut.reg_file.reg_File[9])); all_passed = 0; end

    // Check ADD
    if ($signed(uut.reg_file.reg_File[10]) == 15) $display("✅ [PASS] ADD t2,t0,t1 -> t2 = 15");
    else begin $display("❌ [FAIL] ADD t2,t0,t1 -> t2 = %0d (Expected 15)", $signed(uut.reg_file.reg_File[10])); all_passed = 0; end

    // Check SUB
    if ($signed(uut.reg_file.reg_File[11]) == -12) $display("✅ [PASS] SUB t3,t3,t2 -> t3 = -12");
    else begin $display("❌ [FAIL] SUB t3,t3,t2 -> t3 = %0d (Expected -12)", $signed(uut.reg_file.reg_File[11])); all_passed = 0; end

    // Check Memory SW/LW base
    if ($signed(uut.reg_file.reg_File[16]) == 15) $display("✅ [PASS] LW s0, 0(z)  -> s0 = 15");
    else begin $display("❌ [FAIL] LW s0, 0(z)  -> s0 = %0d (Expected 15)", $signed(uut.reg_file.reg_File[16])); all_passed = 0; end

    // Check Memory SW/LW offset
    if ($signed(uut.reg_file.reg_File[17]) == 7) $display("✅ [PASS] LW s1, 4(z)  -> s1 = 7");
    else begin $display("❌ [FAIL] LW s1, 4(z)  -> s1 = %0d (Expected 7)", $signed(uut.reg_file.reg_File[17])); all_passed = 0; end


    $display("\n--- Memory Verification ---");
    if ($signed(uut.data_mem.ram[0]) == 15) $display("✅ [PASS] SW t2, 0(z)  -> Mem[0] = 15");
    else begin $display("❌ [FAIL] SW t2, 0(z)  -> Mem[0] = %0d (Expected 15)", $signed(uut.data_mem.ram[0])); all_passed = 0; end

    if ($signed(uut.data_mem.ram[1]) == 7) $display("✅ [PASS] SW t5, 4(z)  -> Mem[4] = 7");
    else begin $display("❌ [FAIL] SW t5, 4(z)  -> Mem[4] = %0d (Expected 7)", $signed(uut.data_mem.ram[1])); all_passed = 0; end


    $display("\n=======================================================");
    if (all_passed)
        $display("    SUCCESS: ALL TESTBENCH CHECKS PASSED ");
    else
        $display("️ FAILURE: SOME TESTBENCH CHECKS FAILED ️");
    $display("=======================================================");

    $finish;
end

endmodule