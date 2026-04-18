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

    // -----------------------------
    // CLA ADD/SUB
    // -----------------------------
    wire do_sub = (alu_Control == 3'b110);

    wire [31:0] cla_sum;
    wire cla_cout;
    wire cla_overflow;

    cla_32bit fast_adder (
        .a(src_A),
        .b(src_B),
        .cin(1'b0),
        .sub(do_sub),
        .sum(cla_sum),
        .cout(cla_cout),
        .overflow(cla_overflow)
    );

    // -----------------------------
    // MULTIPLIER (COMBINATIONAL SAFE VERSION)
    // -----------------------------
    wire [63:0] mult_full;
    assign mult_full = src_A * src_B;

    wire [31:0] wallace_res = mult_full[31:0];

    // -----------------------------
    // ALU LOGIC
    // -----------------------------
    always @(*) begin
        alu_Result = 32'd0;
        carry      = 1'b0;
        borrow     = 1'b0;
        overflow   = 1'b0;

        case (alu_Control)

            3'b000: alu_Result = src_A & src_B;          // AND
            3'b001: alu_Result = src_A | src_B;          // OR

            3'b010: begin                                // ADD
                alu_Result = cla_sum;
                carry      = cla_cout;
                overflow   = cla_overflow;
            end

            3'b011: alu_Result = src_A << src_B[4:0];    // SLL

            3'b100: alu_Result = src_A >> src_B[4:0];    // SRL

            3'b101: alu_Result = src_A ^ src_B;          // XOR

            3'b110: begin                                // SUB
                alu_Result = cla_sum;
                borrow     = (src_A < src_B);
                overflow   = cla_overflow;
            end

            3'b111: alu_Result = wallace_res;            // MUL

            default: alu_Result = 32'd0;

        endcase
    end

    // -----------------------------
    // FLAGS
    // -----------------------------
    assign alu_Zero = ~|alu_Result;
    assign parity   = ~^alu_Result;

endmodule