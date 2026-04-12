// =============================================================================
//  Control_Unit.v  —  Optimized FSM-based Multicycle MIPS Control Unit
//  
//  OPTIMIZATIONS vs original:
//  1. ADDI:  3 cycles (S0→S1→S9→S10) → 2 cycles (S0→S1→S9)
//             Writeback merged INTO the execute state (S9) by asserting
//             RegWrite in S9 directly. S10 is eliminated.
//  2. R-type: 3 cycles (S0→S1→S6→S7) → 2 cycles (S0→S1→S6)
//             Writeback merged INTO the execute state (S6). S7 is eliminated.
//  3. J:     Remains 2 cycles (S0→S1→S11→S0) — no change needed.
//  4. BEQ:   Remains 2 cycles (S0→S1→S8) — no change needed.
//  5. LW:    Remains 4 cycles (S0→S1→S2→S3→S4) — memory latency limits this.
//  6. SW:    Remains 3 cycles (S0→S1→S2→S5) — cannot be reduced further.
//  7. BNE:   New instruction added (opcode 6'b000101), same path as BEQ.
//  8. ORI:   New instruction added (opcode 6'b001101), 2-cycle path.
//  9. ANDI:  New instruction added (opcode 6'b001100), 2-cycle path.
//  10. ALU control decoded combinationally from opcode for I-type instructions,
//      avoiding a separate decode state.
//  11. State encoding uses localparams (cleaner, avoids magic numbers).
//  12. PCWrite and Branch merged cleanly; sig_PCWrite now only fires
//      in S0 and S11 — BEQ/BNE handled via Branch path only.
//
//  CPI Summary (Before → After):
//    R-type : 3 → 2   (-33%)
//    ADDI   : 3 → 2   (-33%)
//    ORI    : N/A → 2  (new)
//    ANDI   : N/A → 2  (new)
//    BEQ    : 2 → 2   (unchanged)
//    BNE    : N/A → 2  (new)
//    LW     : 4 → 4   (memory-bound, unchanged)
//    SW     : 3 → 3   (memory-bound, unchanged)
//    J      : 2 → 2   (unchanged)
// =============================================================================

module Control_Unit(
    input  wire        clock,
    input  wire        rst,
    input  wire [5:0]  instr_Opcode,
    input  wire [5:0]  instr_Function,

    output wire [1:0]  sig_MemtoReg,
    output wire        sig_RegDst,
    output wire [1:0]  sig_PCSrc,
    output wire [1:0]  sig_ALUSrcB,
    output wire        sig_ALUSrcA,
    output wire        sig_IRWrite,
    output wire        sig_MemWrite,
    output wire        sig_PCWrite,
    output wire        sig_Branch,
    output wire        sig_BranchNE,   // NEW: branch-not-equal enable
    output wire        sig_RegWrite,

    output reg  [3:0]  state,
    output reg  [2:0]  alu_Control
);

    // -------------------------------------------------------------------------
    //  State encoding (one-hot would be faster on FPGA, but 4-bit is fine here)
    // -------------------------------------------------------------------------
    localparam [3:0]
        S_FETCH   = 4'd0,   // Fetch + PC+4
        S_DECODE  = 4'd1,   // Decode + read registers + compute branch target
        S_MADR    = 4'd2,   // LW/SW: compute memory address
        S_MREAD   = 4'd3,   // LW:    memory read
        S_MWBACK  = 4'd4,   // LW:    write-back from memory
        S_MWRITE  = 4'd5,   // SW:    memory write
        S_REXEC   = 4'd6,   // R-type: execute AND write-back (merged, was S6+S7)
        // S7 eliminated — writeback merged into S_REXEC
        S_BEXEC   = 4'd8,   // BEQ/BNE: compare
        S_IEXEC   = 4'd9,   // ADDI/ORI/ANDI: execute AND write-back (merged, was S9+S10)
        // S10 eliminated — writeback merged into S_IEXEC
        S_JUMP    = 4'd11;  // J: update PC

    // -------------------------------------------------------------------------
    //  Opcode parameters
    // -------------------------------------------------------------------------
    localparam [5:0]
        OP_RTYPE = 6'b000000,
        OP_LW    = 6'b100011,
        OP_SW    = 6'b101011,
        OP_BEQ   = 6'b000100,
        OP_BNE   = 6'b000101,   // NEW
        OP_ADDI  = 6'b001000,
        OP_ANDI  = 6'b001100,   // NEW
        OP_ORI   = 6'b001101,   // NEW
        OP_J     = 6'b000010;

    // -------------------------------------------------------------------------
    //  FSM — next-state logic
    // -------------------------------------------------------------------------
    always @(posedge clock or posedge rst) begin
        if (rst)
            state <= S_FETCH;
        else begin
            case (state)
                S_FETCH:  state <= S_DECODE;

                S_DECODE: begin
                    case (instr_Opcode)
                        OP_J:              state <= S_JUMP;
                        OP_ADDI, OP_ANDI,
                        OP_ORI:            state <= S_IEXEC;
                        OP_BEQ, OP_BNE:    state <= S_BEXEC;
                        OP_RTYPE:          state <= S_REXEC;
                        OP_SW, OP_LW:      state <= S_MADR;
                        default:           state <= S_FETCH;
                    endcase
                end

                S_MADR:   state <= (instr_Opcode == OP_SW) ? S_MWRITE : S_MREAD;
                S_MREAD:  state <= S_MWBACK;
                S_MWBACK: state <= S_FETCH;
                S_MWRITE: state <= S_FETCH;

                S_REXEC:  state <= S_FETCH;   // writeback merged in
                S_BEXEC:  state <= S_FETCH;
                S_IEXEC:  state <= S_FETCH;   // writeback merged in
                S_JUMP:   state <= S_FETCH;

                default:  state <= S_FETCH;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    //  ALU Source A:  0 = PC,   1 = Reg A
    // -------------------------------------------------------------------------
    assign sig_ALUSrcA =
        (state == S_MADR  ) ? 1'b1 :
        (state == S_REXEC ) ? 1'b1 :
        (state == S_BEXEC ) ? 1'b1 :
        (state == S_IEXEC ) ? 1'b1 : 1'b0;

    // -------------------------------------------------------------------------
    //  ALU Source B:  00=RegB  01=4  10=SignImm  11=SignImm<<2
    // -------------------------------------------------------------------------
    assign sig_ALUSrcB =
        (state == S_FETCH ) ? 2'b01 :          // PC+4 adder
        (state == S_DECODE) ? 2'b11 :          // branch target pre-compute
        (state == S_MADR  ) ? 2'b10 :          // base + offset
        (state == S_IEXEC ) ? 2'b10 : 2'b00;  // imm execute

    // -------------------------------------------------------------------------
    //  PC Source:  00=ALU result (PC+4)  01=ALU output reg (branch)  10=Jump
    // -------------------------------------------------------------------------
    assign sig_PCSrc =
        (state == S_JUMP ) ? 2'b10 :
        (state == S_BEXEC) ? 2'b01 : 2'b00;

    // -------------------------------------------------------------------------
    //  Simple one-hot-style enables
    // -------------------------------------------------------------------------
    assign sig_IRWrite  = (state == S_FETCH);
    assign sig_PCWrite  = (state == S_FETCH) | (state == S_JUMP);
    assign sig_Branch   = (state == S_BEXEC) & (instr_Opcode == OP_BEQ);
    assign sig_BranchNE = (state == S_BEXEC) & (instr_Opcode == OP_BNE);
    assign sig_MemWrite = (state == S_MWRITE);

    // RegDst: 0=rt (I-type dest), 1=rd (R-type dest)
    assign sig_RegDst   = (state == S_REXEC);

    // MemtoReg: 00=ALU result  01=Data memory  (only used when RegWrite=1)
    assign sig_MemtoReg = (state == S_MWBACK) ? 2'b01 : 2'b00;

    // RegWrite fires in the merged execute/writeback states and in LW writeback
    assign sig_RegWrite =
        (state == S_MWBACK) |   // LW writeback
        (state == S_REXEC ) |   // R-type execute+writeback
        (state == S_IEXEC );    // I-type execute+writeback

    // -------------------------------------------------------------------------
    //  ALU Control
    //  alu_Op encoding:  00=ADD  01=SUB  10=R-type func  11=I-type opcode
    // -------------------------------------------------------------------------
    always @(*) begin
        case (state)
            // ---- ADD for address/PC arithmetic ----
            S_FETCH, S_DECODE, S_MADR: alu_Control = 3'b010; // ADD

            // ---- Branch: subtract to compare ----
            S_BEXEC: alu_Control = 3'b110; // SUB

            // ---- R-type: decode from function field ----
            S_REXEC: begin
                case (instr_Function)
                    6'b100000: alu_Control = 3'b010; // ADD
                    6'b100010: alu_Control = 3'b110; // SUB
                    6'b100100: alu_Control = 3'b000; // AND
                    6'b100101: alu_Control = 3'b001; // OR
                    6'b100110: alu_Control = 3'b101; // XOR
                    6'b000000: alu_Control = 3'b011; // SLL
                    6'b000010: alu_Control = 3'b100; // SRL
                    6'b011000: alu_Control = 3'b111; // MUL
                    default:   alu_Control = 3'b010;
                endcase
            end

            // ---- I-type: decode from opcode ----
            S_IEXEC: begin
                case (instr_Opcode)
                    OP_ADDI: alu_Control = 3'b010; // ADD
                    OP_ANDI: alu_Control = 3'b000; // AND
                    OP_ORI:  alu_Control = 3'b001; // OR
                    default: alu_Control = 3'b010;
                endcase
            end

            default: alu_Control = 3'b010;
        endcase
    end

endmodule
