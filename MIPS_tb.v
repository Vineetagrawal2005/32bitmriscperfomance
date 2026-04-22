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

// ================= LOAD PROGRAM =================
integer i;
initial begin
    // Clear ROM
    for (i = 0; i < 256; i = i + 1)
        uut.instr_mem.rom[i] = 32'd0;

    // ================= PROGRAM =================
    uut.instr_mem.rom[0]  = 32'h2008_000A;   // ADDI t0,10
    uut.instr_mem.rom[1]  = 32'h2009_0005;   // ADDI t1,5
    uut.instr_mem.rom[2]  = 32'h0109_5020;   // ADD  t2 = 15
    uut.instr_mem.rom[3]  = 32'hAC0A_0000;   // SW   t2 → mem[0]
    uut.instr_mem.rom[4]  = 32'h8C10_0000;   // LW   s0 ← mem[0]

    uut.instr_mem.rom[5]  = 32'h200B_0003;   // ADDI t3,3
    uut.instr_mem.rom[6]  = 32'h016A_5822;   // SUB  t3 = -12

    uut.instr_mem.rom[7]  = 32'h200C_0001;   // ADDI t4,1
    uut.instr_mem.rom[8]  = 32'h1180_0001;   // BEQ (not taken)

    uut.instr_mem.rom[9]  = 32'h200D_0007;   // ADDI t5,7

    uut.instr_mem.rom[10] = 32'h0800_000A;   // J loop
end

// ================= RESET =================
initial begin
    rst = 1;
    #20 rst = 0;
end

// ================= MONITOR =================
initial begin
    $display("Time   PC        Instr       ALU        WD3       MemW RegW");
    $monitor("%4t  %h  %h  %d  %d   %b    %b",
        $time, debug_pc, debug_instr,
        debug_alu, debug_wd3,
        debug_MemWrite, debug_RegWrite);
end

// ================= FINAL CHECK =================
initial begin
    #800;

    $display("\n===== FINAL REGISTER VALUES =====");
    $display("t0 = %d  (expected 10)", uut.reg_file.reg_File[8]);
    $display("t1 = %d  (expected 5)",  uut.reg_file.reg_File[9]);
    $display("t2 = %d  (expected 15)", uut.reg_file.reg_File[10]);
    $display("t3 = %d  (expected -12)", uut.reg_file.reg_File[11]);
    $display("t4 = %d  (expected 1)",  uut.reg_file.reg_File[12]);
    $display("t5 = %d  (expected 7)",  uut.reg_file.reg_File[13]);
    $display("s0 = %d  (expected 15)", uut.reg_file.reg_File[16]);

    $display("\n===== MEMORY =====");
    $display("Mem[0] = %d  (expected 15)", uut.data_mem.ram[0]);

    $display("\n===== RESULT =====");

    if (uut.reg_file.reg_File[8]  == 32'd10 &&
        uut.reg_file.reg_File[9]  == 32'd5  &&
        uut.reg_file.reg_File[10] == 32'd15 &&
        uut.reg_file.reg_File[16] == 32'd15 &&
        uut.data_mem.ram[0]       == 32'd15)
        $display("✅ ALL CHECKS PASSED");
    else
        $display("❌ SOME CHECKS FAILED");

    $finish;
end

endmodule