`timescale 1ns / 1ps

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
output wire        sig_BranchNE,
output wire        sig_RegWrite,

output reg  [3:0]  state,
output reg  [2:0]  alu_Control


);


// ================= STATES =================
localparam [3:0]
    S_FETCH  = 4'd0,
    S_DECODE = 4'd1,
    S_MADR   = 4'd2,
    S_MREAD  = 4'd3,
    S_MWBACK = 4'd4,
    S_MWRITE = 4'd5,
    S_REXEC  = 4'd6,
    S_BEXEC  = 4'd8,
    S_IEXEC  = 4'd9,
    S_JUMP   = 4'd11;

// ================= OPCODES =================
localparam [5:0]
    OP_RTYPE = 6'b000000,
    OP_LW    = 6'b100011,
    OP_SW    = 6'b101011,
    OP_BEQ   = 6'b000100,
    OP_BNE   = 6'b000101,
    OP_ADDI  = 6'b001000,
    OP_ANDI  = 6'b001100,
    OP_ORI   = 6'b001101,
    OP_J     = 6'b000010;

// ================= FSM =================
always @(posedge clock or posedge rst) begin
    if (rst)
        state <= S_FETCH;
    else begin
        case (state)

            S_FETCH:  state <= S_DECODE;

            S_DECODE: begin
                case (instr_Opcode)
                    OP_J:              state <= S_JUMP;
                    OP_ADDI,
                    OP_ANDI,
                    OP_ORI:            state <= S_IEXEC;
                    OP_BEQ,
                    OP_BNE:            state <= S_BEXEC;
                    OP_RTYPE:          state <= S_REXEC;
                    OP_LW,
                    OP_SW:             state <= S_MADR;
                    default:           state <= S_FETCH;
                endcase
            end

            S_MADR:   state <= (instr_Opcode == OP_SW) ? S_MWRITE : S_MREAD;
            S_MREAD:  state <= S_MWBACK;
            S_MWBACK: state <= S_FETCH;
            S_MWRITE: state <= S_FETCH;

            S_REXEC:  state <= S_FETCH;
            S_IEXEC:  state <= S_FETCH;
            S_BEXEC:  state <= S_FETCH;
            S_JUMP:   state <= S_FETCH;

            default:  state <= S_FETCH;
        endcase
    end
end

// ================= CONTROL SIGNALS =================

// ALU SOURCE A
assign sig_ALUSrcA =
    (state == S_MADR  ) ? 1'b1 :
    (state == S_REXEC ) ? 1'b1 :
    (state == S_BEXEC ) ? 1'b1 :
    (state == S_IEXEC ) ? 1'b1 :
                          1'b0;

// ✅ FIXED ALU SOURCE B (VERY IMPORTANT)
assign sig_ALUSrcB =
    (state == S_FETCH ) ? 2'b01 :   // PC + 4
    (state == S_DECODE) ? 2'b11 :   // branch target
    (state == S_MADR  ) ? 2'b10 :   // ⭐ FIXED (SignImm)
    (state == S_IEXEC ) ? 2'b10 :
                          2'b00;    // register

// PC SOURCE
assign sig_PCSrc =
    (state == S_JUMP ) ? 2'b10 :
    (state == S_BEXEC) ? 2'b01 :
                          2'b00;

// BASIC CONTROL
assign sig_IRWrite  = (state == S_FETCH);
assign sig_PCWrite  = (state == S_FETCH) | (state == S_JUMP);
assign sig_MemWrite = (state == S_MWRITE);

// BRANCH CONTROL
assign sig_Branch   = (state == S_BEXEC) & (instr_Opcode == OP_BEQ);
assign sig_BranchNE = (state == S_BEXEC) & (instr_Opcode == OP_BNE);

// REGISTER CONTROL
assign sig_RegDst   = (state == S_REXEC);

assign sig_MemtoReg = (state == S_MWBACK) ? 2'b01 : 2'b00;

assign sig_RegWrite =
    (state == S_MWBACK) |
    (state == S_REXEC ) |
    (state == S_IEXEC );

// ================= ALU CONTROL =================
always @(*) begin
    case (state)

        S_FETCH,
        S_DECODE,
        S_MADR: alu_Control = 3'b010;

        S_BEXEC: alu_Control = 3'b110;

        S_REXEC: begin
            case (instr_Function)
                6'b100000: alu_Control = 3'b010;
                6'b100010: alu_Control = 3'b110;
                6'b100100: alu_Control = 3'b000;
                6'b100101: alu_Control = 3'b001;
                6'b100110: alu_Control = 3'b101;
                6'b000000: alu_Control = 3'b011;
                6'b000010: alu_Control = 3'b100;
                6'b011000: alu_Control = 3'b111;
                default:   alu_Control = 3'b010;
            endcase
        end

        S_IEXEC: begin
            case (instr_Opcode)
                OP_ADDI: alu_Control = 3'b010;
                OP_ANDI: alu_Control = 3'b000;
                OP_ORI:  alu_Control = 3'b001;
                default: alu_Control = 3'b010;
            endcase
        end

        default: alu_Control = 3'b010;
    endcase
end


endmodule
