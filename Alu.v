`timescale 1ns / 1ps

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

    wire [31:0] cla_sum;
    wire        cla_cout;
    wire        cla_overflow;

    cla_32bit fast_adder (
        .a        (src_A),
        .b        (src_B),
        .cin      (1'b0),
        .sub      (alu_Control == 3'b110),
        .sum      (cla_sum),
        .cout     (cla_cout),
        .overflow (cla_overflow)
    );

    wire [63:0] mult_full;
    assign mult_full = src_A * src_B;
    wire [31:0] mult_res = mult_full[31:0];

    always @(*) begin
        alu_Result = 32'd0;
        carry      = 1'b0;
        borrow     = 1'b0;
        overflow   = 1'b0;

        case (alu_Control)
            3'b000: alu_Result = src_A & src_B;
            3'b001: alu_Result = src_A | src_B;
            3'b010: begin
                alu_Result = cla_sum;
                carry      = cla_cout;
                overflow   = cla_overflow;
            end
            3'b011: alu_Result = src_A << src_B[4:0];
            3'b100: alu_Result = src_A >> src_B[4:0];
            3'b101: alu_Result = src_A ^ src_B;
            3'b110: begin
                alu_Result = cla_sum;
                borrow     = ~cla_cout;
                overflow   = cla_overflow;
            end
            3'b111: alu_Result = mult_res;
            default: alu_Result = 32'd0;
        endcase
    end

    assign alu_Zero = ~|alu_Result;
    assign parity   = ~^alu_Result;

endmodule
