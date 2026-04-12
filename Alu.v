// =============================================================================
//  Alu.v  —  Optimized 32-bit MIPS ALU
//
//  OPTIMIZATIONS vs original:
//  1. cla_b_input and cla_cin were registered (reg) even though they are
//     combinationally driven — this created phantom latches in synthesis.
//     Changed to wire, computed via assign outside the always block.
//  2. Carry-lookahead adder is now instantiated with proper select logic
//     driven by wires, so synthesis can correctly optimize the mux-before-
//     adder critical path.
//  3. alu_Zero uses a single bitwise-OR reduction instead of comparison
//     with 32'd0, which maps to a faster tree of OR gates on FPGA.
//  4. SLL/SRL: use src_B[4:0] as shift amount (MIPS standard — shamt field),
//     not hardcoded shift of 1.  When called from Control_Unit for SLL/SRL
//     the shamt comes from instr[10:6] routed through src_B[4:0].
//     NOTE: In the current datapath src_B carries reg_B or immediate;
//     for shift instructions the shamt (instr[10:6]) is passed as the
//     lower bits of src_B.  The top module routes this correctly.
//  5. Overflow flag computed only when relevant (ADD/SUB), not every cycle.
//  6. All flag outputs (carry, borrow, overflow, parity) retained for
//     academic completeness and future branch-on-flag extension.
// =============================================================================

module Alu(
    input  wire [2:0]  alu_Control,
    input  wire [31:0] src_A,
    input  wire [31:0] src_B,

    output reg  [31:0] alu_Result,
    output wire        alu_Zero,
    output reg         carry,
    output reg         borrow,
    output reg         overflow,
    output wire        parity
);

    // -------------------------------------------------------------------------
    //  CLA adder instantiation — wires drive the select (no latches)
    // -------------------------------------------------------------------------
    wire        do_sub  = (alu_Control == 3'b110);  // 1 for SUB, 0 for ADD
    wire [31:0] cla_b   = do_sub ? ~src_B : src_B;
    wire        cla_cin = do_sub ? 1'b1   : 1'b0;

    wire [31:0] cla_sum;
    wire        cla_cout;

    cla_32bit fast_adder (
        .a   (src_A),
        .b   (cla_b),
        .cin (cla_cin),
        .sum (cla_sum),
        .cout(cla_cout)
    );

    // -------------------------------------------------------------------------
    //  Wallace tree multiplier
    // -------------------------------------------------------------------------
    wire [31:0] wallace_res;

    wallace_32bit fast_mult (
        .A         (src_A),
        .B         (src_B),
        .product_lo(wallace_res)
    );

    // -------------------------------------------------------------------------
    //  Main ALU combinational block
    // -------------------------------------------------------------------------
    always @(*) begin
        // Defaults — prevent latches
        alu_Result = 32'd0;
        carry      = 1'b0;
        borrow     = 1'b0;
        overflow   = 1'b0;

        case (alu_Control)
            3'b000: alu_Result = src_A & src_B;                    // AND

            3'b001: alu_Result = src_A | src_B;                    // OR

            3'b010: begin                                           // ADD (CLA)
                alu_Result = cla_sum;
                carry      = cla_cout;
                overflow   = (~src_A[31] & ~src_B[31] &  cla_sum[31])
                           | ( src_A[31] &  src_B[31] & ~cla_sum[31]);
            end

            3'b011: alu_Result = src_A << src_B[4:0];              // SLL (variable)

            3'b100: alu_Result = src_A >> src_B[4:0];              // SRL (variable)

            3'b101: alu_Result = src_A ^ src_B;                    // XOR

            3'b110: begin                                           // SUB (CLA)
                alu_Result = cla_sum;
                borrow     = (src_A < src_B);
                overflow   = ( src_A[31] & ~src_B[31] & ~cla_sum[31])
                           | (~src_A[31] &  src_B[31] &  cla_sum[31]);
            end

            3'b111: alu_Result = wallace_res;                      // MUL

            default: alu_Result = 32'd0;
        endcase
    end

    // -------------------------------------------------------------------------
    //  Zero flag — OR-reduction tree (faster than == 32'd0 on FPGA)
    // -------------------------------------------------------------------------
    assign alu_Zero = ~|alu_Result;

    // -------------------------------------------------------------------------
    //  Parity flag (even parity: 1 when result has even number of 1s)
    // -------------------------------------------------------------------------
    assign parity = ~^alu_Result;

endmodule
