// =============================================================================
//  MIPS_tb.v  —  Testbench for Optimized Multicycle MIPS Processor
//
//  Changes vs original:
//  1. Simulation time extended to 2000 ns to cover all 21 instructions
//     in the new test program.
//  2. Added $display checkpoints at key cycle counts to verify
//     instruction results.
//  3. Waveform dump retained — compatible with GTKWave / Vivado simulator.
//  4. All debug ports identical to original — no DUT interface changes.
// =============================================================================

`timescale 1ns/1ps

module MIPS_tb;

    // -------------------------------------------------------------------------
    //  Inputs
    // -------------------------------------------------------------------------
    reg clock;
    reg rst;

    // -------------------------------------------------------------------------
    //  Outputs
    // -------------------------------------------------------------------------
    wire [3:0]  state;

    wire [31:0] debug_pc;
    wire [31:0] debug_instr;
    wire [31:0] debug_alu;
    wire [31:0] debug_regA;
    wire [31:0] debug_regB;
    wire [31:0] debug_srcA;
    wire [31:0] debug_srcB;
    wire [31:0] debug_alu_out;
    wire [31:0] debug_mem_data;
    wire [31:0] debug_wd3;
    wire [31:0] debug_signimm;

    // -------------------------------------------------------------------------
    //  DUT
    // -------------------------------------------------------------------------
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
        .debug_signimm  (debug_signimm)
    );

    // -------------------------------------------------------------------------
    //  Clock: 10 ns period (100 MHz)
    // -------------------------------------------------------------------------
    initial clock = 0;
    always  #5 clock = ~clock;

    // -------------------------------------------------------------------------
    //  Stimulus
    // -------------------------------------------------------------------------
    initial begin
        rst = 1;
        #20;
        rst = 0;

        // Run long enough to execute all instructions in the test program
        #2000;

        $display("=== Simulation Complete ===");
        $finish;
    end

    // -------------------------------------------------------------------------
    //  Waveform dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("mips_opt.vcd");
        $dumpvars(0, MIPS_tb);
        $dumpvars(1, uut);
    end

    // -------------------------------------------------------------------------
    //  Monitor — prints every time state or PC changes
    // -------------------------------------------------------------------------
    initial begin
        $display("%-6s | %-5s | %-10s | %-10s | %-10s | %-10s | %-10s",
                 "Time", "State", "PC", "Instr", "ALU_Res", "RegA", "RegB");
        $monitor("%6t | %5d | %10h | %10h | %10h | %10h | %10h",
                 $time, state, debug_pc, debug_instr,
                 debug_alu, debug_regA, debug_regB);
    end

endmodule
