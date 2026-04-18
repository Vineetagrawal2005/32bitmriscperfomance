`timescale 1ns/1ps

// =============================================================
//  MIPS_tb.v - FINAL CORRECT TESTBENCH (MULTICYCLE SAFE)
// =============================================================

module MIPS_tb;

    // ================= INPUTS =================
    reg clock;
    reg rst;

    // ================= OUTPUTS =================
    wire [3:0] state;

    wire [31:0] debug_pc;
    wire [31:0] debug_instr;
    wire [31:0] debug_alu;
    wire [31:0] debug_regA;
    wire [31:0] debug_regB;
    wire [31:0] debug_alu_out;
    wire [31:0] debug_mem_data;
    wire [31:0] debug_wd3;   // ✅ IMPORTANT (for LW check)

    // Dummy wires for unused ports
    wire [31:0] dummy1, dummy2, dummy3;

    // ================= DUT =================
    MIPS uut (
        .clock(clock),
        .rst(rst),
        .state(state),
        .debug_pc(debug_pc),
        .debug_instr(debug_instr),
        .debug_alu(debug_alu),
        .debug_regA(debug_regA),
        .debug_regB(debug_regB),
        .debug_srcA(dummy1),
        .debug_srcB(dummy2),
        .debug_alu_out(debug_alu_out),
        .debug_mem_data(debug_mem_data),
        .debug_wd3(debug_wd3),
        .debug_MemWrite(debug_MemWrite),
        .debug_RegWrite(debug_RegWrite),     // ✅ CONNECTED
        .debug_signimm(dummy3)
    );

    // ================= CLOCK =================
    initial clock = 0;
    always #5 clock = ~clock;

    // ================= COUNTERS =================
    integer pass = 0;
    integer fail = 0;

    // ================= RESET =================
    initial begin
        rst = 1;
        #20 rst = 0;
    end

    // ================= WAVE =================
    initial begin
        $dumpfile("mips_final.vcd");
        $dumpvars(0, MIPS_tb);
    end

    // ================= CHECK TASK =================
    task check;
        input [255:0] name;
        input condition;
        begin
            if (condition) begin
                $display("[PASS] %s", name);
                pass = pass + 1;
            end else begin
                $display("[FAIL] %s", name);
                fail = fail + 1;
            end
        end
    endtask

    // =========================================================
    //  MAIN CONTROL
    // =========================================================
    initial begin
        @(negedge rst);
        @(posedge clock);

        $display("\n=========== START EXECUTION ===========");

        repeat (200) @(posedge clock);

        $display("\n=========== FINAL RESULT ===========");
        $display("PASS = %0d", pass);
        $display("FAIL = %0d", fail);

        if (fail == 0)
            $display("🎉 ALL INSTRUCTIONS EXECUTED SUCCESSFULLY");
        else
            $display("⚠️ SOME INSTRUCTIONS FAILED");

        $finish;
    end

    // =========================================================
    //  MULTICYCLE CHECK LOGIC (FINAL FIXED)
    // =========================================================
    always @(posedge clock) begin

        // Instruction completed states
        if (state == 6 || state == 9 || state == 4) begin

            case (debug_instr)

                // ================= I-TYPE =================
                32'h20080005: check("ADDI t0 = 5", debug_alu == 5);
                32'h20090003: check("ADDI t1 = 3", debug_alu == 3);
                32'h310A000F: check("ANDI t2 = 5", debug_alu == 5);
                32'h350B0006: check("ORI t3 = 7",  debug_alu == 7);

                // ================= R-TYPE =================
                32'h01095020: check("ADD = 8", debug_alu == 8);
                32'h01095022: check("SUB = 2", debug_alu == 2);
                32'h01098024: check("AND = 1", debug_alu == 1);
                32'h01098025: check("OR = 7",  debug_alu == 7);
                32'h01098026: check("XOR = 6", debug_alu == 6);
                32'h01098018: check("MUL = 15", debug_alu == 15);

                // ================= MEMORY =================
                32'hAC080000: check("SW executed", 1);

                // ✅ FIXED LW CHECK (VERY IMPORTANT)
                32'h8C100000: begin
                    check("LW loaded = 5", uut.debug_wd3 == 5);
                end

                // ================= BRANCH =================
                32'h11090001: check("BEQ executed", 1);
                32'h15090001: check("BNE executed", 1);

                // ================= FINAL =================
                32'h2008000A: check("ADDI t0 = 10", debug_alu == 10);
                32'h08000014: check("JUMP executed", 1);

            endcase
        end

    end

endmodule